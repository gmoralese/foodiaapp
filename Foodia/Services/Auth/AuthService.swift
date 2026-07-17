import AuthenticationServices
import CryptoKit
import Foundation
import Supabase

/// Sesión de Supabase con Sign in with Apple. Solo autenticación: los datos
/// viajan por el backend, que valida el JWT de esta sesión.
@Observable
final class AuthService {
    static let shared = AuthService()

    /// true hasta que Supabase restaura (o descarta) la sesión guardada.
    private(set) var isRestoring = true
    private(set) var session: Session?

    #if DEBUG
    /// -skipAuth: entra sin cuenta, para desarrollo y screenshots.
    static let skipAuth = ProcessInfo.processInfo.arguments.contains("-skipAuth")
    #endif

    var isAuthenticated: Bool {
        #if DEBUG
        if Self.skipAuth { return true }
        #endif
        return session != nil
    }

    private let client: SupabaseClient

    /// Nonce del intento en curso: a Apple va el SHA-256 y a Supabase el valor
    /// crudo, que verifica que el id_token corresponda a este intento.
    private var currentNonce: String?

    private init() {
        guard let info = Bundle.main.infoDictionary,
              let urlString = info["SupabaseURL"] as? String,
              let url = URL(string: urlString),
              let key = info["SupabasePublishableKey"] as? String else {
            fatalError("Faltan SupabaseURL/SupabasePublishableKey en Info.plist")
        }
        client = SupabaseClient(supabaseURL: url, supabaseKey: key)
    }

    /// Mantiene `session` al día de por vida; llamar una sola vez desde la raíz.
    func start() async {
        #if DEBUG
        // -testLogin correo:contraseña — sesión real por password para poder
        // probar el sync end-to-end en el simulador, donde SIWA no aplica.
        if session == nil,
           let index = ProcessInfo.processInfo.arguments.firstIndex(of: "-testLogin"),
           ProcessInfo.processInfo.arguments.indices.contains(index + 1) {
            let parts = ProcessInfo.processInfo.arguments[index + 1]
                .split(separator: ":", maxSplits: 1)
            if parts.count == 2 {
                do {
                    session = try await client.auth.signIn(
                        email: String(parts[0]), password: String(parts[1])
                    )
                    print("[testLogin] sesión creada")
                } catch {
                    print("[testLogin] falló: \(error)")
                }
            }
        }
        #endif
        for await (event, session) in client.auth.authStateChanges {
            if event == .initialSession {
                // El estado inicial no pisa una sesión ya creada por un login
                // que corrió antes de suscribirse (p. ej. -testLogin).
                self.session = self.session ?? session
                isRestoring = false
            } else {
                self.session = session
            }
        }
    }

    /// id del usuario en auth.users (el `user_id` de todas las tablas).
    var userID: UUID? { session?.user.id }

    /// Access token vigente; refresca contra Supabase si ya expiró.
    func accessToken() async throws -> String {
        try await client.auth.session.accessToken
    }

    /// Sube una foto de comida al bucket privado (folder del usuario) y
    /// devuelve el path que se persiste en meals.photo_path.
    func uploadMealPhoto(_ data: Data, filename: String) async throws -> String {
        guard let userID else { throw AuthError.invalidCredential }
        let path = "\(userID.uuidString.lowercased())/\(filename)"
        try await client.storage.from("meal-photos").upload(
            path,
            data: data,
            options: FileOptions(contentType: "image/jpeg", upsert: true)
        )
        return path
    }

    /// Sube el avatar al bucket privado (folder del usuario), reemplazando el
    /// anterior. Devuelve el path que se persiste en profiles.avatar_path.
    func uploadAvatar(_ data: Data) async throws -> String {
        guard let userID else { throw AuthError.invalidCredential }
        let path = "\(userID.uuidString.lowercased())/avatar.jpg"
        try await client.storage.from("avatars").upload(
            path,
            data: data,
            options: FileOptions(contentType: "image/jpeg", upsert: true)
        )
        return path
    }

    /// Baja el avatar del bucket (para restaurarlo en un dispositivo nuevo).
    func downloadAvatar(_ path: String) async throws -> Data {
        try await client.storage.from("avatars").download(path: path)
    }

    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let nonce = bytes.map { String(format: "%02x", $0) }.joined()
        currentNonce = nonce
        // .fullName: Apple lo entrega SOLO en la primera autorización (lo
        // guardamos como nombre del perfil). .email: identidad de la cuenta en
        // Supabase; el usuario puede ocultarlo con el relay de Apple.
        request.requestedScopes = [.fullName, .email]
        request.nonce = SHA256.hash(data: Data(nonce.utf8))
            .map { String(format: "%02x", $0) }.joined()
    }

    func signInWithApple(_ authorization: ASAuthorization) async throws {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8),
              let nonce = currentNonce else {
            throw AuthError.invalidCredential
        }
        currentNonce = nil
        session = try await client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
        )
        // Apple entrega el nombre SOLO en la primera autorización; si vino, lo
        // guardamos en el perfil (best-effort — se puede editar luego).
        if let components = credential.fullName,
           let name = Self.formatName(components) {
            _ = try? await BackendClient.shared.updateProfile(ProfilePatch(name: name))
        }
    }

    private static func formatName(_ components: PersonNameComponents) -> String? {
        let name = PersonNameComponentsFormatter().string(from: components)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : String(name.prefix(80))
    }

    func signOut() async {
        try? await client.auth.signOut()
        session = nil
        AvatarStore.clear()
    }

    enum AuthError: Error {
        case invalidCredential
    }
}
