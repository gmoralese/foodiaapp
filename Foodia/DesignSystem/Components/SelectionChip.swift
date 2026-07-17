import SwiftUI

/// Chip de selección (onboarding). Seleccionado = relleno acento; el estado
/// también se expone a VoiceOver via trait.
struct SelectionChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? Color.white : .dsTextPrimary)
                .padding(.horizontal, 16)
                .frame(minHeight: 40)
                .background(
                    isSelected ? Color.dsAccent : .dsCard,
                    in: .capsule
                )
                .overlay {
                    if !isSelected {
                        Capsule().strokeBorder(Color.dsHairline, lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    HStack {
        SelectionChip(title: "🏋️ Fuerza", isSelected: true) {}
        SelectionChip(title: "🏃 Running", isSelected: false) {}
    }
    .padding()
    .background(Color.dsBackground)
}
