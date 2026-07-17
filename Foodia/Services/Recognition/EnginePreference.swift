import Foundation

/// Preferencia del usuario sobre qué motor analiza sus fotos.
enum EnginePreference: String, CaseIterable {
    /// VLM local (o Vision como fallback): privado, offline, gratis.
    case local
    /// Backend propio con Vertex AI Gemini: máxima precisión, requiere conexión.
    /// Si falla, se muestra el error con opciones (no hay fallback silencioso).
    case cloud
    /// Nube con conexión; si no hay, Local — fallback silencioso.
    case auto

    static let storageKey = "preferredEngine"

    static var current: EnginePreference {
        EnginePreference(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .auto
    }
}
