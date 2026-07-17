import SwiftUI

/// Card de hidratación del dashboard: progreso hacia la meta diaria de agua
/// con botones rápidos. Azul (dsFat) como refuerzo, nunca única señal.
struct HydrationCard: View {
    let consumedMl: Double
    let goalMl: Double
    var onAdd: (Double) -> Void

    private var progress: Double {
        guard goalMl > 0 else { return 0 }
        return min(consumedMl / goalMl, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label {
                    Text("Hidratación")
                        .font(.dsSection)
                        .foregroundStyle(Color.dsTextPrimary)
                } icon: {
                    DSIcon(id: "droplets", size: 18, tint: .dsFat)
                }
                Spacer()
                Text("\(Int(consumedMl)) / \(Int(goalMl)) ml")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.dsTextPrimary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.dsHairline)
                    Capsule()
                        .fill(Color.dsFat)
                        .frame(width: max(proxy.size.width * progress, consumedMl > 0 ? 6 : 0))
                        .animation(.easeOut(duration: 0.4), value: progress)
                }
            }
            .frame(height: 6)
            HStack(spacing: 8) {
                addButton("＋ Vaso · 250 ml", amount: 250)
                addButton("＋ 500 ml", amount: 500)
            }
        }
        .padding(16)
        .background(Color.dsCard, in: .rect(cornerRadius: DSRadius.card, style: .continuous))
        .sensoryFeedback(.increase, trigger: consumedMl)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Hidratación: \(Int(consumedMl)) de \(Int(goalMl)) mililitros")
    }

    private func addButton(_ title: LocalizedStringKey, amount: Double) -> some View {
        Button {
            onAdd(amount)
        } label: {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.dsGreenText)
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(Color.dsGreenTint, in: .capsule)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HydrationCard(consumedMl: 1250, goalMl: 2000) { _ in }
        .padding()
        .background(Color.dsBackground)
}
