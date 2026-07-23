import Foundation

/// Regla PURA del "día" de una medición corporal, extraída para testear sin UI ni
/// SwiftData (mismo criterio que `RemoteMerge`).
nonisolated enum MeasurementDay {
    /// Mediodía UTC del día calendario (local) de `date`. Se usa como `measuredAt`
    /// al guardar para que el bucket "por día" del backend (día en UTC) coincida
    /// con el día que eligió la persona, sin depender de la hora ni de la zona:
    /// el mediodía UTC cae en la misma fecha para cualquier huso realista (±12 h).
    static func normalizedToNoonUTC(_ date: Date, calendar: Calendar = .current) -> Date {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        var noon = DateComponents()
        noon.year = comps.year
        noon.month = comps.month
        noon.day = comps.day
        noon.hour = 12
        return utc.date(from: noon) ?? date
    }
}
