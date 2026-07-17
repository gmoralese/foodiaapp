import SwiftUI

/// Card de comida del dashboard/historial: tile de emoji o foto,
/// título + ingredientes · hora, y kcal a la derecha.
struct MealRow: View {
    let title: String
    let subtitle: String
    let icon: String
    var photo: UIImage?
    let kcal: Int

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let photo {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(.rect(cornerRadius: DSRadius.thumb, style: .continuous))
                } else {
                    FoodIconTile(icon: icon)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.dsRowTitle)
                    .foregroundStyle(Color.dsTextPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.dsTextSecondary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text("\(kcal)")
                    .font(.dsRowValue)
                    .foregroundStyle(Color.dsTextPrimary)
                    .monospacedDigit()
                Text("kcal")
                    .font(.caption2)
                    .foregroundStyle(Color.dsTextTertiary)
            }
        }
        .padding(12)
        .background(Color.dsCard, in: .rect(cornerRadius: DSRadius.card, style: .continuous))
    }
}

#Preview {
    VStack(spacing: 10) {
        MealRow(title: "Almuerzo", subtitle: "Arroz, pollo, ensalada · 13:05", icon: "wheat", kcal: 640)
        MealRow(title: "Merienda", subtitle: "Manzana, yogur · 17:30", icon: "apple", kcal: 180)
    }
    .padding()
    .background(Color.dsBackground)
}
