import SwiftUI

/// Card del resumen diario generado con Apple Intelligence.
/// Solo se muestra en equipos compatibles; si no, no aparece (sin hueco).
struct AISummaryCard: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("RESUMEN DEL DÍA", systemImage: "sparkle")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.dsGreenText)
                .kerning(0.5)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Color.dsTextPrimary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            Text("Generado con Apple Intelligence en tu iPhone")
                .font(.system(size: 11))
                .foregroundStyle(Color.dsTextTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.dsCard, in: .rect(cornerRadius: DSRadius.card, style: .continuous))
    }
}

#Preview {
    AISummaryCard(text: "Vas por 78 g de proteína, 52 % de tu meta. Los carbos vienen justos; te quedan 660 kcal para la cena.")
        .padding()
        .background(Color.dsBackground)
}
