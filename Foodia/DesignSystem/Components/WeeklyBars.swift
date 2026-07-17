import SwiftUI

/// Mini gráfico de barras de la semana (dashboard). Verde suave = en meta,
/// ámbar = excedido, acento = hoy.
struct WeeklyBars: View {
    struct Day: Identifiable {
        let id: Date
        let letter: String
        let kcal: Double
        let isToday: Bool
    }

    let days: [Day]
    let goal: Double

    private var maxValue: Double {
        max(goal * 1.15, days.map(\.kcal).max() ?? 0, 1)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(days) { day in
                VStack(spacing: 5) {
                    Capsule()
                        .fill(barColor(day))
                        .frame(width: 14, height: max(6, 64 * day.kcal / maxValue))
                        .frame(maxWidth: .infinity, maxHeight: 64, alignment: .bottom)
                    Text(day.letter)
                        .font(.system(size: 10, weight: day.isToday ? .bold : .medium))
                        .foregroundStyle(day.isToday ? Color.dsAccent : .dsTextTertiary)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(day.letter): \(Int(day.kcal)) calorías\(day.kcal > goal ? ", excedido" : "")")
            }
        }
        .frame(height: 84, alignment: .bottom)
    }

    private func barColor(_ day: Day) -> Color {
        if day.isToday { return .dsAccent }
        return day.kcal > goal ? .dsBarOver : .dsBarMeta
    }
}
