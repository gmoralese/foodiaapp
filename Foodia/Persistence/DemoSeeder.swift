#if DEBUG
import Foundation
import SwiftData

/// Datos de demostración para desarrollo y screenshots.
/// Se activa lanzando la app con el argumento `-seedDemo`.
@MainActor
enum DemoSeeder {
    static func seed(_ container: ModelContainer) {
        let context = container.mainContext
        let existing = (try? context.fetchCount(FetchDescriptor<MealEntry>())) ?? 0
        guard existing == 0 else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        func add(_ name: String, _ icon: String, grams: Double, kcal: Double,
                 p: Double, c: Double, f: Double, daysAgo: Int, hour: Int, group: UUID) {
            let day = calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today
            let timestamp = calendar.date(bySettingHour: hour, minute: Int.random(in: 0...50), second: 0, of: day) ?? day
            context.insert(MealEntry(
                timestamp: timestamp, name: name, emoji: "🍽️", grams: grams,
                calories: kcal, proteinG: p, carbsG: c, fatG: f,
                photoFilename: nil, confirmedByUser: true, mealGroupID: group,
                icon: icon
            ))
        }

        // Hoy: desayuno + almuerzo + merienda (parecido al mockup)
        let breakfast = UUID()
        add("Huevos", "egg", grams: 100, kcal: 155, p: 13, c: 1, f: 11, daysAgo: 0, hour: 8, group: breakfast)
        add("Tostadas", "wheat", grams: 40, kcal: 116, p: 4, c: 22, f: 1, daysAgo: 0, hour: 8, group: breakfast)
        add("Aguacate", "apple", grams: 70, kcal: 112, p: 1, c: 6, f: 10, daysAgo: 0, hour: 8, group: breakfast)
        let lunch = UUID()
        add("Arroz", "wheat", grams: 180, kcal: 234, p: 5, c: 50, f: 1, daysAgo: 0, hour: 13, group: lunch)
        add("Pollo grillado", "drumstick", grams: 160, kcal: 264, p: 50, c: 0, f: 6, daysAgo: 0, hour: 13, group: lunch)
        add("Ensalada", "salad", grams: 120, kcal: 24, p: 2, c: 4, f: 0, daysAgo: 0, hour: 13, group: lunch)
        let snack = UUID()
        add("Manzana", "apple", grams: 180, kcal: 94, p: 1, c: 25, f: 0, daysAgo: 0, hour: 17, group: snack)
        add("Yogur", "milk", grams: 170, kcal: 104, p: 6, c: 8, f: 6, daysAgo: 0, hour: 17, group: snack)

        // Días anteriores (para la semana y el historial)
        for daysAgo in 1...9 {
            let kcalBase: Double = daysAgo == 4 ? 2_310 : Double(Int.random(in: 1_650...1_950))
            let dinner = UUID()
            add("Comida del día", "utensils-crossed", grams: 400, kcal: kcalBase * 0.45,
                p: 40, c: 80, f: 22, daysAgo: daysAgo, hour: 13, group: dinner)
            let dinner2 = UUID()
            add("Cena", "soup", grams: 350, kcal: kcalBase * 0.55,
                p: 38, c: 92, f: 26, daysAgo: daysAgo, hour: 21, group: dinner2)
        }

        try? context.save()
    }
}
#endif
