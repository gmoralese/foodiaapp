import SwiftUI

enum AppTab: Hashable {
    case today
    case history
    case goals
    case settings
}

/// Tab bar custom del diseño: 3 destinos + botón de cámara central elevado.
/// La cámara es una acción, no un lugar donde estar — por eso no es un tab.
struct FoodiaTabBar: View {
    @Binding var selection: AppTab
    var onCamera: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            // 2+2 alrededor del botón central: simetría perfecta.
            HStack(spacing: 0) {
                tabItem(.today, title: "Hoy", systemImage: "house")
                tabItem(.history, title: "Historial", systemImage: "clock")
            }
            .frame(maxWidth: .infinity)
            Color.clear.frame(width: 76, height: 1)
            HStack(spacing: 0) {
                tabItem(.goals, title: "Metas", systemImage: "target")
                tabItem(.settings, title: "Ajustes", systemImage: "gearshape")
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.top, 6)
        .padding(.horizontal, 12)
        .background {
            Rectangle()
                .fill(.bar)
                .overlay(alignment: .top) {
                    Color.dsHairline.frame(height: 0.5)
                }
                .ignoresSafeArea(edges: .bottom)
        }
        // Franja transparente sobre la barra: reserva el saliente del botón
        // (y su glow) dentro del safe area para que nunca tape el contenido.
        .padding(.top, 34)
        // El botón vive en un overlay: centrado exacto en el ancho de la barra.
        .overlay(alignment: .top) {
            cameraButton
                .offset(y: 10)
        }
    }

    private func tabItem(_ tab: AppTab, title: LocalizedStringKey, systemImage: String) -> some View {
        let isActive = selection == tab
        return Button {
            selection = tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .medium))
                    .symbolVariant(isActive ? .fill : .none)
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(isActive ? Color.dsAccent : .dsTextTertiary)
            .frame(maxWidth: .infinity, minHeight: 46)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: selection)
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
    }

    private var cameraButton: some View {
        Button(action: onCamera) {
            Image(systemName: "camera.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(Color.dsAccent, in: .circle)
                .shadow(color: Color.dsAccent.opacity(0.35), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Registrar comida con la cámara")
    }
}

#Preview {
    @Previewable @State var tab = AppTab.today
    VStack {
        Spacer()
        FoodiaTabBar(selection: $tab) {}
    }
    .background(Color.dsBackground)
}
