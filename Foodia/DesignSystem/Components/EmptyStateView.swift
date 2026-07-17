import SwiftUI

/// Patrón de estado vacío: emoji grande + título + cuerpo + CTA pill.
/// Nunca una pantalla en blanco.
struct EmptyStateView: View {
    let icon: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var ctaTitle: LocalizedStringKey?
    var ctaSystemImage: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            DSIcon(id: icon, size: 44, tint: .dsTextTertiary)
            Text(title)
                .font(.dsSection)
                .foregroundStyle(Color.dsTextPrimary)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.dsTextSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let ctaTitle, let action {
                Button(action: action) {
                    Label(ctaTitle, systemImage: ctaSystemImage ?? "camera.fill")
                        .font(.dsButton)
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 22)
                        .frame(minHeight: 46)
                        .background(Color.dsAccent, in: .capsule)
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 24)
    }
}

#Preview {
    EmptyStateView(
        icon: "utensils-crossed",
        title: "Todavía no registraste nada",
        message: "Tómale una foto a tu próxima comida y Foodia calcula los macros por vos.",
        ctaTitle: "Tomar foto"
    ) {}
        .background(Color.dsBackground)
}
