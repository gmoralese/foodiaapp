import SwiftUI

/// Avatar circular del usuario: foto cacheada, si no las iniciales del nombre,
/// si no un ícono de persona. Tamaño configurable.
struct AvatarView: View {
    var image: UIImage?
    var name: String?
    var size: CGFloat = 56

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let initials {
                Text(initials)
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(Color.dsGreenText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.dsGreenTint)
            } else {
                DSIcon(id: "user", size: size * 0.5, tint: .dsTextSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.dsInset)
            }
        }
        .frame(width: size, height: size)
        .clipShape(.circle)
    }

    private var initials: String? {
        guard let name = name?.trimmingCharacters(in: .whitespaces), !name.isEmpty else {
            return nil
        }
        let letters = name.split(separator: " ").prefix(2).compactMap(\.first)
        return letters.isEmpty ? nil : String(letters).uppercased()
    }
}
