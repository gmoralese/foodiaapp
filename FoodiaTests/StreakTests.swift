import Foundation
import Testing

@testable import Foodia

@Suite("Streak — días consecutivos")
struct StreakTests {
    private let calendar = Calendar.current
    private var today: Date { calendar.startOfDay(for: .now) }

    /// Fecha a `offset` días de hoy (offset negativo = pasado).
    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: today)!
    }

    @Test("sin registros la racha es 0")
    func emptyIsZero() {
        #expect(Streak.days(from: [], calendar: calendar) == 0)
    }

    @Test("solo hoy cuenta 1")
    func todayOnly() {
        #expect(Streak.days(from: [day(0)], calendar: calendar) == 1)
    }

    @Test("días consecutivos terminando hoy se acumulan")
    func consecutiveEndingToday() {
        #expect(Streak.days(from: [day(0), day(-1), day(-2)], calendar: calendar) == 3)
    }

    @Test("hoy sin registrar no rompe la racha si ayer sí")
    func graceWhenTodayMissing() {
        #expect(Streak.days(from: [day(-1), day(-2)], calendar: calendar) == 2)
    }

    @Test("si el último registro es anteayer, la racha ya se rompió")
    func brokenWhenLatestIsTwoDaysAgo() {
        #expect(Streak.days(from: [day(-2), day(-3)], calendar: calendar) == 0)
    }

    @Test("un hueco corta la racha en el tramo más reciente")
    func gapCutsStreak() {
        // hoy y anteayer, sin ayer → solo cuenta hoy.
        #expect(Streak.days(from: [day(0), day(-2), day(-3)], calendar: calendar) == 1)
    }

    @Test("varios registros el mismo día cuentan como un solo día")
    func multipleEntriesSameDayCountOnce() {
        let noon = calendar.date(byAdding: .hour, value: 12, to: today)!
        let evening = calendar.date(byAdding: .hour, value: 20, to: today)!
        #expect(Streak.days(from: [noon, evening, day(-1)], calendar: calendar) == 2)
    }

    @Test("el orden de los timestamps no afecta el resultado")
    func orderIndependent() {
        #expect(Streak.days(from: [day(-2), day(0), day(-1)], calendar: calendar) == 3)
    }
}
