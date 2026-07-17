import Foundation

/// Cliente de los endpoints autenticados del backend (perfil, comidas, agua).
/// Cada request lleva el access token de Supabase; el backend lo valida
/// contra el JWKS del proyecto.
struct BackendClient {
    static let shared = BackendClient()

    enum APIError: Error {
        case badStatus(Int)
    }

    private let baseURL: URL

    private init() {
        guard let urlString = Bundle.main.object(forInfoDictionaryKey: "BackendURL") as? String,
              let url = URL(string: urlString) else {
            fatalError("Falta BackendURL en Info.plist")
        }
        baseURL = url
    }

    // MARK: Perfil

    func profile() async throws -> RemoteProfile {
        try await get("v1/profile")
    }

    @discardableResult
    func updateProfile(_ patch: ProfilePatch) async throws -> RemoteProfile {
        try await send("PATCH", "v1/profile", body: patch)
    }

    // MARK: Comidas

    func createMeal(_ payload: CreateMealPayload) async throws -> RemoteMeal {
        try await send("POST", "v1/meals", body: payload)
    }

    func meals(cursor: String?, limit: Int = 50) async throws -> RemoteMealPage {
        try await get("v1/meals", query: pageQuery(cursor: cursor, limit: limit))
    }

    func deleteMeal(id: UUID) async throws {
        try await delete("v1/meals/\(id.uuidString.lowercased())")
    }

    // MARK: Agua

    @discardableResult
    func createWater(milliliters: Double, loggedAt: Date) async throws -> RemoteWaterEntry {
        try await send(
            "POST", "v1/water",
            body: CreateWaterPayload(milliliters: milliliters, loggedAt: loggedAt)
        )
    }

    func water(cursor: String?, limit: Int = 50) async throws -> RemoteWaterPage {
        try await get("v1/water", query: pageQuery(cursor: cursor, limit: limit))
    }

    func deleteWater(id: UUID) async throws {
        try await delete("v1/water/\(id.uuidString.lowercased())")
    }

    // MARK: Plomería

    private func pageQuery(cursor: String?, limit: Int) -> [URLQueryItem] {
        var items = [URLQueryItem(name: "limit", value: String(limit))]
        if let cursor {
            items.append(URLQueryItem(name: "cursor", value: cursor))
        }
        return items
    }

    private func get<Response: Decodable>(
        _ path: String, query: [URLQueryItem] = []
    ) async throws -> Response {
        let data = try await perform(makeRequest("GET", path, query: query))
        return try Self.decoder.decode(Response.self, from: data)
    }

    private func send<Response: Decodable>(
        _ method: String, _ path: String, body: some Encodable
    ) async throws -> Response {
        var request = try await makeRequest(method, path)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try Self.encoder.encode(body)
        let data = try await perform(request)
        return try Self.decoder.decode(Response.self, from: data)
    }

    private func delete(_ path: String) async throws {
        // 404 cuenta como éxito: el recurso ya no está (borrado idempotente).
        do {
            _ = try await perform(makeRequest("DELETE", path))
        } catch APIError.badStatus(404) {}
    }

    private func makeRequest(
        _ method: String, _ path: String, query: [URLQueryItem] = []
    ) async throws -> URLRequest {
        var url = baseURL.appending(path: path)
        if !query.isEmpty {
            url.append(queryItems: query)
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        let token = try await AuthService.shared.accessToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200...299).contains(status) else {
            throw APIError.badStatus(status)
        }
        return data
    }

    // El backend serializa fechas como ISO-8601 con milisegundos.
    private static let decoder: JSONDecoder = {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let raw = try decoder.singleValueContainer().decode(String.self)
            guard let date = withFraction.date(from: raw) ?? plain.date(from: raw) else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Fecha inválida: \(raw)"
                ))
            }
            return date
        }
        return decoder
    }()

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

// MARK: - DTOs

struct RemoteProfile: Decodable {
    let onboardingStep: Int
    let onboardingCompletedAt: Date?
    let sex: String?
    let age: Int?
    let weightKg: Double?
    let heightCm: Double?
    let activity: String?
    let sports: [String]
    let objective: String?
    let planName: String?
    let goalKcal: Double?
    let goalProteinG: Double?
    let goalCarbsG: Double?
    let goalFatG: Double?
    let goalWaterMl: Double?
    let foodCountry: String?
}

/// PATCH parcial: los nil no se envían (el backend no toca esos campos).
struct ProfilePatch: Encodable {
    var onboardingStep: Int? = nil
    var onboardingCompleted: Bool? = nil
    var sex: String? = nil
    var age: Int? = nil
    var weightKg: Double? = nil
    var heightCm: Double? = nil
    var activity: String? = nil
    var sports: [String]? = nil
    var objective: String? = nil
    var planName: String? = nil
    var goalKcal: Double? = nil
    var goalProteinG: Double? = nil
    var goalCarbsG: Double? = nil
    var goalFatG: Double? = nil
    var goalWaterMl: Double? = nil
    var foodCountry: String? = nil
}

struct RemoteMealComponent: Decodable {
    let id: UUID
    let name: String
    let icon: String?
    let emoji: String?
    let grams: Double
    let kcal: Double
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let category: String?
}

struct RemoteMeal: Decodable {
    let id: UUID
    let eatenAt: Date
    let mealType: String
    let photoPath: String?
    let note: String?
    let engine: String?
    let model: String?
    let components: [RemoteMealComponent]
}

struct RemoteMealPage: Decodable {
    let items: [RemoteMeal]
    let nextCursor: String?
}

struct ComponentPayload: Encodable {
    let name: String
    let icon: String?
    let emoji: String?
    let grams: Double
    let kcal: Double
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
}

struct CreateMealPayload: Encodable {
    let mealType: String
    let eatenAt: Date
    let engine: String?
    let photoPath: String?
    let components: [ComponentPayload]
}

struct CreateWaterPayload: Encodable {
    let milliliters: Double
    let loggedAt: Date
}

struct RemoteWaterEntry: Decodable {
    let id: UUID
    let loggedAt: Date
    let milliliters: Double
}

struct RemoteWaterPage: Decodable {
    let items: [RemoteWaterEntry]
    let nextCursor: String?
}
