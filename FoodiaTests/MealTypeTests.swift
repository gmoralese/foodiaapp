import Foundation
import Testing

@testable import Foodia

@Suite("MealType.inferred — sugerencia por hora")
struct MealTypeTests {
    /// Hoy a la hora dada, en el calendario/zona actual (los mismos que usa inferred).
    private func at(_ hour: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: .now)!
    }

    @Test("5–10 h sugiere desayuno", arguments: [5, 8, 10])
    func morningIsBreakfast(hour: Int) {
        #expect(MealType.inferred(from: at(hour)) == .breakfast)
    }

    @Test("11–14 h sugiere almuerzo", arguments: [11, 12, 14])
    func middayIsLunch(hour: Int) {
        #expect(MealType.inferred(from: at(hour)) == .lunch)
    }

    @Test("15–18 h sugiere merienda", arguments: [15, 16, 18])
    func afternoonIsSnack(hour: Int) {
        #expect(MealType.inferred(from: at(hour)) == .snack)
    }

    @Test("19 h en adelante y madrugada sugieren cena", arguments: [19, 21, 23, 0, 3])
    func nightIsDinner(hour: Int) {
        #expect(MealType.inferred(from: at(hour)) == .dinner)
    }
}
