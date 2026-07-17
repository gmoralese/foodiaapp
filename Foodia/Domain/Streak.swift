import Foundation

/// Racha: días consecutivos con al menos una comida registrada,
/// terminando hoy o ayer (hoy sin registrar aún no rompe la racha).
nonisolated enum Streak {
    static func days(from timestamps: [Date], calendar: Calendar = .current) -> Int {
        let daysWithEntries = Set(timestamps.map { calendar.startOfDay(for: $0) })
        guard !daysWithEntries.isEmpty else { return 0 }

        var day = calendar.startOfDay(for: .now)
        if !daysWithEntries.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day),
                  daysWithEntries.contains(yesterday) else { return 0 }
            day = yesterday
        }
        var streak = 0
        while daysWithEntries.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }
}
