import Foundation

/// Foto del día que la app comparte con el widget vía App Group.
/// Este archivo se compila en la app Y en la extensión del widget.
nonisolated struct WidgetSnapshot: Codable {
    var kcal: Double
    var kcalGoal: Double
    var protein: Double
    var proteinGoal: Double
    var carbs: Double
    var carbsGoal: Double
    var fat: Double
    var fatGoal: Double
    var streak: Int
    var updated: Date

    static let suiteName = "group.me.gusmorales.foodia"
    static let key = "widgetSnapshot"

    static func load() -> WidgetSnapshot? {
        guard let data = UserDefaults(suiteName: suiteName)?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults(suiteName: Self.suiteName)?.set(data, forKey: Self.key)
    }

    /// El snapshot es de otro día: el widget arranca el día en cero.
    var isStale: Bool {
        !Calendar.current.isDateInToday(updated)
    }
}
