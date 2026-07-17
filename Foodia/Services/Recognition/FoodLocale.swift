import Foundation

/// Idioma y país para la capa de IA: los nombres de comida cambian por país
/// (palta/aguacate, frutilla/fresa), así que la IA responde según el país del
/// usuario — mientras que la UI de la app sigue el idioma del sistema (es/en).
nonisolated enum FoodLocale {
    static let countryKey = "foodCountry"

    /// Países hispanohablantes + EE. UU., para los pickers.
    static let countries = [
        "AR", "BO", "CL", "CO", "CR", "CU", "DO", "EC", "SV", "GT",
        "HN", "MX", "NI", "PA", "PY", "PE", "PR", "ES", "US", "UY", "VE",
    ]

    static var country: String {
        UserDefaults.standard.string(forKey: countryKey)
            ?? Locale.current.region?.identifier
            ?? "CO"
    }

    static func setCountry(_ code: String) {
        UserDefaults.standard.set(code, forKey: countryKey)
    }

    /// Idioma efectivo de la UI ("es" o "en"), según la localización activa.
    static var appLanguage: String {
        let preferred = Bundle.main.preferredLocalizations.first ?? "es"
        return preferred.hasPrefix("en") ? "en" : "es"
    }

    /// Locale que se envía a los motores de IA: "es-CL", "es-MX" o "en".
    static var analysisLocale: String {
        appLanguage == "en" ? "en" : "es-\(country)"
    }

    static func countryName(for code: String) -> String {
        Locale.current.localizedString(forRegionCode: code) ?? code
    }
}
