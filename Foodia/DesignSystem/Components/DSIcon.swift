import LucideIcons
import SwiftUI

/// Ícono Lucide tintado, integrado al design system.
struct DSIcon: View {
    let id: String
    var size: CGFloat = 20
    var tint: Color = .dsGreenText

    var body: some View {
        if let image = UIImage(lucideId: id) {
            Image(uiImage: image)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .foregroundStyle(tint)
        } else {
            Image(systemName: "questionmark")
                .font(.system(size: size * 0.8))
                .foregroundStyle(tint)
        }
    }
}

/// Tile redondeado de alimento/comida: reemplaza al emoji en las filas.
struct FoodIconTile: View {
    let icon: String
    var size: CGFloat = 50
    var tint: Color = .dsGreenText

    var body: some View {
        DSIcon(id: icon, size: size * 0.46, tint: tint)
            .frame(width: size, height: size)
            .background(Color.dsInset, in: .rect(cornerRadius: DSRadius.thumb, style: .continuous))
    }
}

#Preview {
    HStack(spacing: 10) {
        FoodIconTile(icon: "apple")
        FoodIconTile(icon: "egg-fried")
        FoodIconTile(icon: "utensils-crossed")
        DSIcon(id: "flame", tint: .dsOver)
    }
    .padding()
    .background(Color.dsBackground)
}
