import SwiftData
import SwiftUI

/// Detalle de una comida: foto (si hay), totales con macros y cada alimento
/// con sus gramos y su desglose P/C/G. Se llega tocando una comida en el
/// detalle del día.
struct MealDetailView: View {
    let meal: MealGroup

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false

    private var totals: Macros { meal.totals }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let photo = PhotoStore.load(meal.photoFilename) {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .clipShape(.rect(cornerRadius: DSRadius.large, style: .continuous))
                }
                summaryCard
                Text("Alimentos")
                    .font(.dsSection)
                    .foregroundStyle(Color.dsTextPrimary)
                VStack(spacing: 1) {
                    ForEach(meal.entries) { entry in
                        componentRow(entry)
                    }
                }
                .background(Color.dsCard, in: .rect(cornerRadius: DSRadius.card, style: .continuous))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Color.dsBackground)
        .navigationTitle(meal.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    Image(systemName: "trash")
                }
                .tint(Color.dsRed)
            }
        }
        .confirmationDialog(
            "¿Eliminar esta comida? No se puede deshacer.",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive) { deleteMeal() }
            Button("Cancelar", role: .cancel) {}
        }
    }

    // MARK: Resumen

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(Int(totals.kcal))")
                    .font(.system(size: 34, weight: .heavy))
                    .foregroundStyle(Color.dsTextPrimary)
                    .monospacedDigit()
                Text("kcal")
                    .font(.headline)
                    .foregroundStyle(Color.dsTextSecondary)
                Spacer()
                Text(meal.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(Color.dsTextTertiary)
            }
            HStack(spacing: 8) {
                macroTile("Proteínas", totals.protein, .dsProtein)
                macroTile("Carbos", totals.carbs, .dsCarb)
                macroTile("Grasas", totals.fat, .dsFat)
            }
        }
        .padding(16)
        .background(Color.dsCard, in: .rect(cornerRadius: DSRadius.card, style: .continuous))
    }

    private func macroTile(_ label: LocalizedStringKey, _ grams: Double, _ color: Color) -> some View {
        VStack(spacing: 3) {
            Text("\(Int(grams)) g")
                .font(.footnote.weight(.bold))
                .foregroundStyle(color)
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.dsTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.dsInset, in: .rect(cornerRadius: 10, style: .continuous))
    }

    // MARK: Alimentos

    private func componentRow(_ entry: MealEntry) -> some View {
        HStack(spacing: 12) {
            FoodIconTile(icon: entry.icon ?? FoodCategory.dish.lucideId, size: 44)
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(entry.name)
                        .font(.dsRowTitle)
                        .foregroundStyle(Color.dsTextPrimary)
                    Spacer(minLength: 8)
                    Text("\(Int(entry.calories)) kcal")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.dsTextPrimary)
                        .monospacedDigit()
                }
                HStack(spacing: 10) {
                    Text("\(Int(entry.grams)) g")
                        .font(.caption2)
                        .foregroundStyle(Color.dsTextTertiary)
                    macroChip("P", entry.proteinG, .dsProtein)
                    macroChip("C", entry.carbsG, .dsCarb)
                    macroChip("G", entry.fatG, .dsFat)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(12)
    }

    private func macroChip(_ label: String, _ grams: Double, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text("\(label) \(Int(grams))")
                .font(.caption2)
                .foregroundStyle(Color.dsTextSecondary)
                .monospacedDigit()
        }
    }

    private func deleteMeal() {
        SyncService.shared.deleteRemoteMeal(meal.entries.first?.remoteMealID)
        for entry in meal.entries {
            modelContext.delete(entry)
        }
        try? modelContext.save()
        dismiss()
    }
}
