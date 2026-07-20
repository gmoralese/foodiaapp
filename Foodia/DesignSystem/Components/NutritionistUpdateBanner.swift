import SwiftUI

/// Aviso in-app cuando el nutricionista ajustó tus metas desde el portal (E4).
/// Se muestra en Hoy y en Metas hasta que lo descartas. No ocupa espacio si no
/// hay novedad.
struct NutritionistUpdateBanner: View {
    @State private var goals = GoalsStore.shared

    var body: some View {
        if goals.goalsUpdatedByPro {
            HStack(spacing: 10) {
                DSIcon(id: "stethoscope", size: 18, tint: .dsGreenText)
                Text("Tu nutricionista actualizó tus metas.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.dsTextPrimary)
                Spacer(minLength: 8)
                Button {
                    goals.goalsUpdatedByPro = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.dsTextSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(
                Color.dsGreenTint,
                in: .rect(cornerRadius: DSRadius.card, style: .continuous)
            )
        }
    }
}
