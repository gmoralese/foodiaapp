import Foundation

/// Categoría de una comida. El usuario la elige al guardar (con un default
/// inferido por la hora); nunca se cataloga sola.
nonisolated enum MealType: String, Codable, CaseIterable {
    case breakfast
    case lunch
    case dinner
    case snack

    var title: String {
        switch self {
        case .breakfast: String(localized: "Desayuno")
        case .lunch: String(localized: "Almuerzo")
        case .dinner: String(localized: "Cena")
        case .snack: String(localized: "Merienda o colación")
        }
    }

    var emoji: String {
        switch self {
        case .breakfast: "🌅"
        case .lunch: "☀️"
        case .dinner: "🌙"
        case .snack: "🍎"
        }
    }

    /// Sugerencia inicial según la hora — el usuario siempre puede cambiarla.
    static func inferred(from date: Date) -> MealType {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<11: return .breakfast
        case 11..<15: return .lunch
        case 15..<19: return .snack
        default: return .dinner
        }
    }
}
