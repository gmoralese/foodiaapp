import SwiftUI

/// Anillo de calorías del dashboard. Variantes: en meta (verde) y
/// excedido (ámbar + etiqueta "+N kcal" — nunca solo color).
struct KcalRing: View {
    let consumed: Double
    let goal: Double
    var size: CGFloat = 118
    var lineWidth: CGFloat = 11

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(consumed / goal, 1)
    }

    private var isOver: Bool {
        consumed > goal && goal > 0
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.dsHairline, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    isOver ? Color.dsOver : .dsAccent,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: progress)
            VStack(spacing: 2) {
                Text("\(Int(consumed))")
                    .font(.dsBigNumber)
                    .foregroundStyle(consumed == 0 ? Color.dsTextTertiary : .dsTextPrimary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                if isOver {
                    Text("+\(Int(consumed - goal)) kcal")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.dsOver)
                } else {
                    Text("de \(Int(goal)) kcal")
                        .font(.caption)
                        .foregroundStyle(Color.dsTextSecondary)
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Calorías: \(Int(consumed)) de \(Int(goal))\(isOver ? ", meta excedida" : "")")
    }
}

#Preview("En meta / excedido") {
    HStack(spacing: 24) {
        KcalRing(consumed: 1240, goal: 1900)
        KcalRing(consumed: 2130, goal: 1900)
        KcalRing(consumed: 0, goal: 1900)
    }
    .padding()
    .background(Color.dsBackground)
}
