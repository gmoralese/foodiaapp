import SwiftUI

/// Stepper de gramos en cápsula (paso 5 g, mantener presionado acelera vía
/// repetición del sistema). Tocar el valor selecciona el campo numérico.
struct GramStepper: View {
    @Binding var grams: Double
    var range: ClosedRange<Double> = 5...1000
    var step: Double = 5
    var unit: String = "g"

    var body: some View {
        HStack(spacing: 0) {
            repeatButton("minus") {
                grams = max(range.lowerBound, grams - step)
            }
            Text(unit.isEmpty ? "\(Int(grams))" : "\(Int(grams)) \(unit)")
                .font(.dsRowValue)
                .foregroundStyle(Color.dsTextPrimary)
                .monospacedDigit()
                .frame(minWidth: 52)
                .contentTransition(.numericText())
            repeatButton("plus") {
                grams = min(range.upperBound, grams + step)
            }
        }
        .frame(height: 36)
        .background(Color.dsInset, in: .capsule)
        .sensoryFeedback(.increase, trigger: grams)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Gramos")
        .accessibilityValue("\(Int(grams)) gramos")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: grams = min(range.upperBound, grams + step)
            case .decrement: grams = max(range.lowerBound, grams - step)
            @unknown default: break
            }
        }
    }

    private func repeatButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.footnote.weight(.bold))
                .foregroundStyle(Color.dsGreenText)
                .frame(width: 40, height: 36)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .buttonRepeatBehavior(.enabled)
    }
}

#Preview {
    @Previewable @State var grams = 150.0
    GramStepper(grams: $grams)
        .padding()
        .background(Color.dsBackground)
}
