import SwiftUI

/// Barra horizontal de progreso de un macro. Siempre con etiqueta y valores:
/// el color es refuerzo, nunca la única señal.
struct MacroBar: View {
    let name: LocalizedStringKey
    let consumed: Double
    let goal: Double
    let color: Color

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(consumed / goal, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.dsTextSecondary)
                Spacer()
                Text("\(Int(consumed)) / \(Int(goal)) g")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.dsTextPrimary)
                    .monospacedDigit()
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.dsHairline)
                    Capsule()
                        .fill(color)
                        .frame(width: max(proxy.size.width * progress, consumed > 0 ? 6 : 0))
                        .animation(.easeOut(duration: 0.5), value: progress)
                }
            }
            .frame(height: 6)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name): \(Int(consumed)) de \(Int(goal)) gramos")
    }
}

#Preview {
    VStack(spacing: 14) {
        MacroBar(name: "Proteínas", consumed: 78, goal: 150, color: .dsProtein)
        MacroBar(name: "Carbos", consumed: 142, goal: 190, color: .dsCarb)
        MacroBar(name: "Grasas", consumed: 41, goal: 55, color: .dsFat)
    }
    .padding()
    .background(Color.dsBackground)
}
