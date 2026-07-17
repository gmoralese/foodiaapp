import UIKit

nonisolated enum RemoteRecognitionError: LocalizedError {
    case unauthorized
    case server(Int)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .unauthorized: String(localized: "el backend rechazó la API key")
        case .server(let code): String(localized: "el backend respondió \(code)")
        case .invalidResponse: String(localized: "respuesta inesperada del backend")
        }
    }
}

/// Motor "Nube": envía la foto al backend de Foodia (NestJS + Vertex AI Gemini)
/// y recibe los componentes con gramos y macros estimados.
/// La configuración (URL y API key) vive en Info.plist vía project.yml.
struct RemoteFoodRecognizer {
    let baseURL: URL
    let apiKey: String

    /// Falla si el backend no está configurado en el build.
    init?() {
        guard let urlString = Bundle.main.object(forInfoDictionaryKey: "BackendURL") as? String,
              let url = URL(string: urlString), !urlString.isEmpty,
              let key = Bundle.main.object(forInfoDictionaryKey: "BackendAPIKey") as? String,
              !key.isEmpty else {
            return nil
        }
        baseURL = url
        apiKey = key
    }

    func recognize(in image: UIImage, context: String? = nil) async throws -> [RecognizedComponent] {
        // ~1024 px es suficiente para Gemini y mantiene el upload liviano.
        let scaled = PhotoStore.downscale(image, maxDimension: 1024)
        guard let jpeg = scaled.jpegData(compressionQuality: 0.7) else {
            throw RecognitionError.invalidImage
        }
        return try await send(jpeg: jpeg, context: context)
    }

    /// Registro sin foto: la descripción del usuario es la única entrada.
    func recognize(description: String) async throws -> [RecognizedComponent] {
        try await send(jpeg: nil, context: description)
    }

    private func send(jpeg: Data?, context: String?) async throws -> [RecognizedComponent] {

        var request = URLRequest(url: baseURL.appending(path: "v1/analyze"))
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        // Identidad best-effort: la API key autentica la ruta; el JWT (si hay
        // sesión) le permite al backend atribuir el análisis al usuario en su
        // telemetría de costo. Sin sesión, el análisis igual procede (anónimo).
        if let token = try? await AuthService.shared.accessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let boundary = "foodia-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.multipartBody(jpeg: jpeg, context: context, boundary: boundary)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw RemoteRecognitionError.invalidResponse
        }
        switch http.statusCode {
        case 200, 201: break
        case 401: throw RemoteRecognitionError.unauthorized
        default: throw RemoteRecognitionError.server(http.statusCode)
        }

        guard let decoded = try? JSONDecoder().decode(AnalysisResponse.self, from: data) else {
            throw RemoteRecognitionError.invalidResponse
        }
        return decoded.components.map { component in
            RecognizedComponent(
                name: component.name,
                grams: component.grams,
                displayName: component.displayName,
                // El backend manda macros de la porción completa; la app trabaja
                // por 100 g para que el ajuste de gramos re-escale.
                per100g: component.macros.flatMap { macros in
                    guard component.grams > 0 else { return nil }
                    return Macros(
                        kcal: macros.kcal,
                        protein: macros.protein,
                        carbs: macros.carbs,
                        fat: macros.fat
                    ).scaled(by: 100 / component.grams)
                },
                category: component.category.flatMap(FoodCategory.init(rawValue:))
            )
        }
    }

    private static func multipartBody(jpeg: Data?, context: String?, boundary: String) -> Data {
        var body = Data()
        // Idioma/país para los nombres de comida (palta vs aguacate).
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"locale\"\r\n\r\n".utf8))
        body.append(Data("\(FoodLocale.analysisLocale)\r\n".utf8))
        if let context, !context.isEmpty {
            // El backend acota a 300; cortamos aquí también por prolijidad.
            let trimmed = String(context.prefix(300))
            body.append(Data("--\(boundary)\r\n".utf8))
            body.append(Data("Content-Disposition: form-data; name=\"context\"\r\n\r\n".utf8))
            body.append(Data("\(trimmed)\r\n".utf8))
        }
        if let jpeg {
            body.append(Data("--\(boundary)\r\n".utf8))
            body.append(Data("Content-Disposition: form-data; name=\"photo\"; filename=\"meal.jpg\"\r\n".utf8))
            body.append(Data("Content-Type: image/jpeg\r\n\r\n".utf8))
            body.append(jpeg)
            body.append(Data("\r\n".utf8))
        }
        body.append(Data("--\(boundary)--\r\n".utf8))
        return body
    }
}

private nonisolated struct AnalysisResponse: Decodable {
    struct Component: Decodable {
        struct MacrosPayload: Decodable {
            let kcal: Double
            let protein: Double
            let carbs: Double
            let fat: Double
        }

        let name: String
        let displayName: String?
        let grams: Double
        let macros: MacrosPayload?
        let category: String?
    }

    let components: [Component]
    let model: String
}
