import Foundation

/// Categoría visual de un alimento. Ningún set de íconos tiene los 90
/// alimentos de la base (ni existe el ícono de "arepa"), así que cada
/// alimento cae a su categoría, con override de ícono específico cuando
/// Lucide lo tiene (manzana, pizza, huevo…).
nonisolated enum FoodCategory: String, Codable, CaseIterable {
    case fruit
    case vegetable
    case grain
    case protein
    case dairy
    case drink
    case dessert
    case dish

    /// Ícono Lucide de la categoría (fallback cuando no hay override).
    var lucideId: String {
        switch self {
        case .fruit: "apple"
        case .vegetable: "carrot"
        case .grain: "wheat"
        case .protein: "beef"
        case .dairy: "milk"
        case .drink: "cup-soda"
        case .dessert: "cake-slice"
        case .dish: "utensils-crossed"
        }
    }
}
