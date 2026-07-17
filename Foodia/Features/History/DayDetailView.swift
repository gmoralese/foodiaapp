import SwiftData
import SwiftUI

/// Detalle de un día del historial: totales + comidas.
struct DayDetailView: View {
    let date: Date

    @Environment(\.modelContext) private var modelContext
    @Query private var allEntries: [MealEntry]

    private var goals: DailyGoals { GoalsStore.shared.goals }

    private var entries: [MealEntry] {
        allEntries.filter { Calendar.current.isDate($0.timestamp, inSameDayAs: date) }
    }

    private var meals: [MealGroup] {
        MealGroup.group(entries).sorted { $0.timestamp < $1.timestamp }
    }

    private var totals: Macros { entries.dailyTotals }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 18) {
                    KcalRing(consumed: totals.kcal, goal: goals.kcal, size: 96, lineWidth: 9)
                    VStack(spacing: 10) {
                        MacroBar(name: "Proteínas", consumed: totals.protein, goal: goals.protein, color: .dsProtein)
                        MacroBar(name: "Carbos", consumed: totals.carbs, goal: goals.carbs, color: .dsCarb)
                        MacroBar(name: "Grasas", consumed: totals.fat, goal: goals.fat, color: .dsFat)
                    }
                }
                .padding(16)
                .background(Color.dsCard, in: .rect(cornerRadius: DSRadius.large, style: .continuous))

                Text("Comidas")
                    .font(.dsSection)
                    .foregroundStyle(Color.dsTextPrimary)
                ForEach(meals) { meal in
                    MealRow(
                        title: meal.title,
                        subtitle: "\(meal.ingredients) · \(meal.timestamp.formatted(date: .omitted, time: .shortened))",
                        subtitleLineLimit: nil,
                        icon: meal.icon,
                        photo: PhotoStore.load(meal.photoFilename),
                        kcal: Int(meal.totals.kcal)
                    )
                    .contextMenu {
                        Button("Eliminar", systemImage: "trash", role: .destructive) {
                            SyncService.shared.deleteRemoteMeal(meal.entries.first?.remoteMealID)
                            for entry in meal.entries {
                                modelContext.delete(entry)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Color.dsBackground)
        .navigationTitle(date.formatted(.dateTime.weekday(.wide).day().month()))
        .navigationBarTitleDisplayMode(.inline)
    }
}
