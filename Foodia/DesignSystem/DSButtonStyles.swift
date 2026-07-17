import SwiftUI

/// Botón primario: relleno acento, texto blanco, 52 pt, radio 16 continuo.
struct DSPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.dsButton)
            .foregroundStyle(isEnabled ? Color.white : .dsTextTertiary)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                isEnabled
                    ? (configuration.isPressed ? Color.dsAccentPressed : .dsAccent)
                    : .dsInset,
                in: .rect(cornerRadius: 16, style: .continuous)
            )
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Botón tinted: fondo verde suave, texto verde (ej. "Reanalizar").
struct DSTintedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.dsButton)
            .foregroundStyle(Color.dsGreenText)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Color.dsGreenTint, in: .rect(cornerRadius: DSRadius.row, style: .continuous))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

/// Botón destructivo tinted (siempre acompañado de confirmación).
struct DSDestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.dsButton)
            .foregroundStyle(Color.dsRed)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Color.dsRedTint, in: .rect(cornerRadius: DSRadius.row, style: .continuous))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

/// Botón secundario neutro ("Continuar sin cuenta", "Ahora no").
struct DSSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.dsButton)
            .foregroundStyle(Color.dsTextPrimary)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Color.dsInset, in: .rect(cornerRadius: DSRadius.row, style: .continuous))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

extension ButtonStyle where Self == DSPrimaryButtonStyle {
    static var dsPrimary: DSPrimaryButtonStyle { .init() }
}
extension ButtonStyle where Self == DSTintedButtonStyle {
    static var dsTinted: DSTintedButtonStyle { .init() }
}
extension ButtonStyle where Self == DSDestructiveButtonStyle {
    static var dsDestructive: DSDestructiveButtonStyle { .init() }
}
extension ButtonStyle where Self == DSSecondaryButtonStyle {
    static var dsSecondary: DSSecondaryButtonStyle { .init() }
}
