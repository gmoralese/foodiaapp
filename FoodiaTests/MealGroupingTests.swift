import Foundation
import Testing

@testable import Foodia

@MainActor
@Suite("MealGroup — agrupamiento y totales")
struct MealGroupingTests {
    private func entry(
        _ name: String,
        kcal: Double = 0, protein: Double = 0, carbs: Double = 0, fat: Double = 0,
        group: UUID,
        at date: Date = .now,
        mealType: String? = nil,
        icon: String? = nil
    ) -> MealEntry {
        MealEntry(
            timestamp: date, name: name, emoji: "🍽️", grams: 100,
            calories: kcal, proteinG: protein, carbsG: carbs, fatG: fat,
            photoFilename: nil, confirmedByUser: true,
            mealGroupID: group, mealType: mealType, icon: icon
        )
    }

    @Test("dailyTotals suma los macros de todas las entradas")
    func dailyTotalsSumsEntries() {
        let entries = [
            entry("a", kcal: 100, protein: 10, carbs: 20, fat: 5, group: UUID()),
            entry("b", kcal: 50, protein: 5, carbs: 10, fat: 2, group: UUID()),
        ]
        #expect(entries.dailyTotals == Macros(kcal: 150, protein: 15, carbs: 30, fat: 7))
    }

    @Test("group junta las entradas por mealGroupID y ordena por fecha descendente")
    func groupsByMealGroupIDSortedByDate() {
        let g1 = UUID()
        let g2 = UUID()
        let now = Date.now
        let older = now.addingTimeInterval(-3600)
        let entries = [
            entry("rice", group: g1, at: older),
            entry("egg", group: g1, at: older.addingTimeInterval(60)),
            entry("apple", group: g2, at: now),
        ]
        let groups = MealGroup.group(entries)
        #expect(groups.count == 2)
        // g2 es el más reciente → primero; g1 agrupa dos entradas.
        #expect(groups[0].entries.count == 1)
        #expect(groups[1].entries.count == 2)
    }

    @Test("totals suma los macros de las entradas del grupo")
    func totalsSumsGroupEntries() {
        let g = UUID()
        let group = MealGroup(id: g.uuidString, timestamp: .now, entries: [
            entry("rice", kcal: 200, protein: 5, carbs: 40, fat: 1, group: g),
            entry("egg", kcal: 90, protein: 6, carbs: 1, fat: 7, group: g),
        ])
        #expect(group.totals == Macros(kcal: 290, protein: 11, carbs: 41, fat: 8))
    }

    @Test("ingredients une los componentes con la inicial en mayúscula")
    func ingredientsFormatting() {
        let g = UUID()
        let group = MealGroup(id: g.uuidString, timestamp: .now, entries: [
            entry("Arroz", group: g),
            entry("Huevo frito", group: g),
        ])
        #expect(group.ingredients == "Arroz, huevo frito")
    }

    @Test("title usa la categoría elegida por el usuario cuando existe")
    func titleUsesChosenMealType() {
        let g = UUID()
        let group = MealGroup(id: g.uuidString, timestamp: .now, entries: [
            entry("x", group: g, mealType: MealType.lunch.rawValue),
        ])
        #expect(group.title == MealType.lunch.title)
    }

    @Test("title infiere por hora cuando no hay categoría (datos viejos)")
    func titleFallsBackToInferred() {
        let morning = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: .now)!
        let g = UUID()
        let group = MealGroup(id: g.uuidString, timestamp: morning, entries: [
            entry("x", group: g, at: morning),
        ])
        #expect(group.title == MealType.inferred(from: morning).title)
    }

    @Test("icon toma el primer componente con ícono")
    func iconUsesFirstAvailable() {
        let g = UUID()
        let group = MealGroup(id: g.uuidString, timestamp: .now, entries: [
            entry("x", group: g, icon: nil),
            entry("y", group: g, icon: "apple"),
        ])
        #expect(group.icon == "apple")
    }

    @Test("icon cae a la categoría 'plato' cuando ningún componente trae ícono")
    func iconFallsBackToDish() {
        let g = UUID()
        let group = MealGroup(id: g.uuidString, timestamp: .now, entries: [
            entry("x", group: g, icon: nil),
        ])
        #expect(group.icon == FoodCategory.dish.lucideId)
    }
}
