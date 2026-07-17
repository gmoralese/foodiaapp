import SwiftUI

/// Pill que indica qué motor analizó la foto. Aparece solo en el resumen;
/// tocarlo puede explicar el motor (lo maneja el contenedor).
struct EngineBadge: View {
    enum Kind {
        case local
        case cloud
        case autoUsedLocal

        var label: String {
            switch self {
            case .local: String(localized: "Local")
            case .cloud: String(localized: "Nube")
            case .autoUsedLocal: String(localized: "Auto · usó Local")
            }
        }

        var systemImage: String {
            switch self {
            case .local, .autoUsedLocal: "lock.fill"
            case .cloud: "cloud.fill"
            }
        }
    }

    let kind: Kind

    private var foreground: Color {
        switch kind {
        case .local: .dsGreenText
        case .cloud: .dsCloudText
        case .autoUsedLocal: .dsTextSecondary
        }
    }

    private var background: Color {
        switch kind {
        case .local: .dsGreenTint
        case .cloud: .dsCloudTint
        case .autoUsedLocal: .dsInset
        }
    }

    var body: some View {
        Label(kind.label, systemImage: kind.systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(background, in: .capsule)
    }
}

#Preview {
    HStack {
        EngineBadge(kind: .local)
        EngineBadge(kind: .cloud)
        EngineBadge(kind: .autoUsedLocal)
    }
    .padding()
    .background(Color.dsBackground)
}
