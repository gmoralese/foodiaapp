import Foundation
import Testing

@testable import Foodia

@Suite("MeasurementDay — día de la medición (mediodía UTC)")
struct MeasurementDayTests {
    /// Una hora de la noche en Chile cae al día siguiente en UTC; aun así el día de
    /// la medición debe ser el día LOCAL elegido, fijado al mediodía UTC.
    @Test("normaliza al mediodía UTC del día local, aunque sea de noche")
    func normalizesEveningToNoonUTCOfLocalDay() throws {
        var chile = Calendar(identifier: .gregorian)
        chile.timeZone = try #require(TimeZone(identifier: "America/Santiago"))
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 7
        comps.day = 20
        comps.hour = 23
        comps.minute = 30
        let date = try #require(chile.date(from: comps))

        let noon = MeasurementDay.normalizedToNoonUTC(date, calendar: chile)

        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = try #require(TimeZone(identifier: "UTC"))
        let out = utc.dateComponents([.year, .month, .day, .hour, .minute], from: noon)
        #expect(out.year == 2026)
        #expect(out.month == 7)
        #expect(out.day == 20)
        #expect(out.hour == 12)
        #expect(out.minute == 0)
    }

    /// Dos horas distintas del mismo día local caen en el mismo instante normalizado
    /// (mismo bucket por día → el backend hace upsert sobre la misma fila).
    @Test("dos horas del mismo día colapsan al mismo instante")
    func sameDayCollapsesToSameInstant() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = try #require(TimeZone(identifier: "America/Santiago"))
        let morning = try #require(cal.date(from: DateComponents(year: 2026, month: 7, day: 20, hour: 8)))
        let evening = try #require(cal.date(from: DateComponents(year: 2026, month: 7, day: 20, hour: 22)))

        #expect(
            MeasurementDay.normalizedToNoonUTC(morning, calendar: cal)
                == MeasurementDay.normalizedToNoonUTC(evening, calendar: cal)
        )
    }
}
