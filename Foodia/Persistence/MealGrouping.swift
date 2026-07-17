import Foundation

/// Una "comida" para la UI: los MealEntry guardados desde una misma foto
/// (mismo mealGroupID) o una entrada suelta.
struct MealGroup: Identifiable {
    let id: String
    let timestamp: Date
    let entries: [MealEntry]

    var title: String {
        // Prioriza la categoría elegida por el usuario; infiere por hora
        // solo para datos viejos sin categoría.
        if let raw = entries.compactMap(\.mealType).first,
           let type = MealType(rawValue: raw) {
            return type.title
        }
        return MealType.inferred(from: timestamp).title
    }

    /// "Arroz, huevo frito, aguacate" — los componentes de la comida.
    var ingredients: String {
        let joined = entries.map { $0.name.lowercased() }.joined(separator: ", ")
        return joined.prefix(1).uppercased() + joined.dropFirst()
    }

    /// Ícono Lucide de la comida (primer componente con ícono).
    var icon: String {
        entries.compactMap(\.icon).first ?? FoodCategory.dish.lucideId
    }

    var photoFilename: String? {
        entries.compactMap(\.photoFilename).first
    }

    var totals: Macros {
        entries.reduce(Macros()) { $0 + $1.macros }
    }

    static func group(_ entries: [MealEntry]) -> [MealGroup] {
        let byGroup = Dictionary(grouping: entries) { entry in
            entry.mealGroupID?.uuidString ?? entry.persistentModelID.hashValue.description
        }
        return byGroup.map { key, groupEntries in
            MealGroup(
                id: key,
                timestamp: groupEntries.map(\.timestamp).min() ?? .now,
                entries: groupEntries
            )
        }
        .sorted { $0.timestamp > $1.timestamp }
    }
}

extension [MealEntry] {
    var dailyTotals: Macros {
        reduce(Macros()) { $0 + $1.macros }
    }
}
