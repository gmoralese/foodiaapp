import SwiftUI

/// Toast de confirmación ("✓ Comida guardada"). Se muestra 2 s y desaparece.
struct ToastModifier: ViewModifier {
    @Binding var message: String?

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let message {
                Label(message, systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.dsGreenText)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Color.dsGreenTint, in: .capsule)
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(for: .seconds(2))
                        withAnimation(.easeOut) { self.message = nil }
                    }
            }
        }
        .animation(.spring(duration: 0.35), value: message)
    }
}

extension View {
    func toast(message: Binding<String?>) -> some View {
        modifier(ToastModifier(message: message))
    }
}
