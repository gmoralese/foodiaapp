import AuthenticationServices
import SwiftUI

/// Login obligatorio: Sign in with Apple crea la sesión de Supabase.
/// `onFinish` se llama solo con la sesión ya establecida.
struct LoginView: View {
    var onFinish: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var signingIn = false
    @State private var errorBanner = false

    var body: some View {
        VStack(spacing: 18) {
            if errorBanner {
                errorCard
            }
            Spacer()
            circles
            Text("Guarda tu progreso")
                .font(.dsHeadline)
                .foregroundStyle(Color.dsTextPrimary)
            Text("Con tu cuenta, el diario y tus metas quedan respaldados y se sincronizan entre tus dispositivos.")
                .font(.callout)
                .foregroundStyle(Color.dsTextSecondary)
                .multilineTextAlignment(.center)
            Spacer()
            signInButton
            Text("Apple solo comparte lo que autorices. Puedes ocultar tu\ncorreo real y editar tu nombre cuando quieras.")
                .font(.caption)
                .foregroundStyle(Color.dsTextTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .background(Color.dsBackground)
    }

    private var signInButton: some View {
        SignInWithAppleButton(.continue) { request in
            AuthService.shared.prepareAppleRequest(request)
        } onCompletion: { result in
            switch result {
            case .success(let authorization):
                signingIn = true
                withAnimation { errorBanner = false }
                Task {
                    do {
                        try await AuthService.shared.signInWithApple(authorization)
                        onFinish()
                    } catch {
                        signingIn = false
                        withAnimation { errorBanner = true }
                    }
                }
            case .failure(let error):
                // Cancelar el sheet de Apple no es un error.
                if (error as? ASAuthorizationError)?.code != .canceled {
                    withAnimation { errorBanner = true }
                }
            }
        }
        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
        .frame(height: 52)
        .clipShape(.rect(cornerRadius: DSRadius.card, style: .continuous))
        .opacity(signingIn ? 0.5 : 1)
        .overlay {
            if signingIn { ProgressView() }
        }
        .disabled(signingIn)
    }

    private var errorCard: some View {
        HStack(alignment: .top, spacing: 10) {
            DSIcon(id: "triangle-alert", size: 20, tint: .dsRed)
            VStack(alignment: .leading, spacing: 3) {
                Text("No pudimos iniciar sesión")
                    .font(.dsRowTitle)
                    .foregroundStyle(Color.dsRed)
                Text("Revisa tu conexión a internet e inténtalo de nuevo.")
                    .font(.caption)
                    .foregroundStyle(Color.dsTextSecondary)
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dsRedTint, in: .rect(cornerRadius: DSRadius.card, style: .continuous))
    }

    private var circles: some View {
        HStack(spacing: -12) {
            authCircle("smartphone", size: 72)
            authCircle("refresh-cw", size: 84, tinted: true).zIndex(1).offset(y: -8)
            authCircle("laptop", size: 72)
        }
    }

    private func authCircle(_ icon: String, size: CGFloat, tinted: Bool = false) -> some View {
        DSIcon(id: icon, size: size * 0.38, tint: tinted ? .dsGreenText : .dsTextSecondary)
            .frame(width: size, height: size)
            .background(tinted ? Color.dsGreenTint : .dsCard, in: .circle)
            .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
    }
}
