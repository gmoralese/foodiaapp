import SwiftData
import SwiftUI
import WidgetKit

/// Dashboard "Hoy": responde "¿cómo voy hoy?" en menos de un segundo.
struct TodayView: View {
    var onCapture: () -> Void
    var onSeeAll: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MealEntry.timestamp, order: .reverse) private var allEntries: [MealEntry]
    @Query private var waterEntries: [WaterEntry]
    @State private var summary: String?

    private var goals: DailyGoals { GoalsStore.shared.goals }

    private var todayEntries: [MealEntry] {
        allEntries.filter { Calendar.current.isDateInToday($0.timestamp) }
    }

    private var meals: [MealGroup] {
        // Cronológico: desayuno arriba, como en el diseño.
        MealGroup.group(todayEntries).sorted { $0.timestamp < $1.timestamp }
    }

    private var totals: Macros {
        todayEntries.dailyTotals
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                NutritionistUpdateBanner()
                kcalCard
                if let summary {
                    AISummaryCard(text: summary)
                }
                if meals.isEmpty {
                    emptyState
                } else {
                    mealsSection
                }
                hydrationCard
                weekCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Color.dsBackground)
        .refreshable {
            await SyncService.shared.refresh()
        }
        .task(id: todayEntries.count) {
            publishWidgetSnapshot()
            await generateSummaryIfPossible()
        }
    }

    private var streak: Int {
        Streak.days(from: allEntries.map(\.timestamp))
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(.footnote.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(Color.dsGreenText)
                    .kerning(0.5)
                Text("Hoy")
                    .font(.dsScreenTitle)
                    .foregroundStyle(Color.dsTextPrimary)
            }
            Spacer()
            if streak >= 2 {
                HStack(spacing: 4) {
                    DSIcon(id: "flame", size: 16, tint: .dsOver)
                    Text("\(streak)")
                        .font(.dsRowValue)
                        .foregroundStyle(Color.dsTextPrimary)
                        .monospacedDigit()
                    Text("días")
                        .font(.caption)
                        .foregroundStyle(Color.dsTextSecondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.dsCard, in: .capsule)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Racha de \(streak) días")
            }
        }
        .padding(.top, 8)
    }

    private var kcalCard: some View {
        HStack(spacing: 18) {
            KcalRing(consumed: totals.kcal, goal: goals.kcal)
            VStack(spacing: 12) {
                MacroBar(name: "Proteínas", consumed: totals.protein, goal: goals.protein, color: .dsProtein)
                MacroBar(name: "Carbos", consumed: totals.carbs, goal: goals.carbs, color: .dsCarb)
                MacroBar(name: "Grasas", consumed: totals.fat, goal: goals.fat, color: .dsFat)
            }
        }
        .padding(16)
        .background(Color.dsCard, in: .rect(cornerRadius: DSRadius.large, style: .continuous))
    }

    private var mealsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Comidas de hoy")
                    .font(.dsSection)
                    .foregroundStyle(Color.dsTextPrimary)
                Spacer()
                if let onSeeAll {
                    Button("Ver todo", action: onSeeAll)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.dsGreenText)
                }
            }
            ForEach(meals) { meal in
                MealRow(
                    title: meal.title,
                    subtitle: "\(meal.ingredients) · \(meal.timestamp.formatted(date: .omitted, time: .shortened))",
                    icon: meal.icon,
                    photo: PhotoStore.load(meal.photoFilename),
                    kcal: Int(meal.totals.kcal)
                )
                .contextMenu {
                    Button("Eliminar", systemImage: "trash", role: .destructive) {
                        delete(meal)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            EmptyStateView(
                icon: "utensils-crossed",
                title: "Todavía no registraste nada",
                message: "Tómale una foto a tu próxima comida y Foodia calcula los macros por vos.",
                ctaTitle: "Tomar foto",
                action: onCapture
            )
            HStack(alignment: .top, spacing: 8) {
                DSIcon(id: "lightbulb", size: 18, tint: .dsOver)
                Text("**Tip:** también puedes elegir una foto de la galería, o dictarle a la IA qué comiste si no tienes foto.")
                    .font(.footnote)
                    .foregroundStyle(Color.dsTextSecondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.dsInset, in: .rect(cornerRadius: DSRadius.row, style: .continuous))
        }
    }

    private var weekCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Esta semana")
                    .font(.dsSection)
                    .foregroundStyle(Color.dsTextPrimary)
                Spacer()
                Text("promedio \(Int(weekAverage)) kcal")
                    .font(.caption)
                    .foregroundStyle(Color.dsTextSecondary)
            }
            WeeklyBars(days: weekDays, goal: goals.kcal)
        }
        .padding(16)
        .background(Color.dsCard, in: .rect(cornerRadius: DSRadius.card, style: .continuous))
    }

    private var todayWaterMl: Double {
        waterEntries
            .filter { Calendar.current.isDateInToday($0.timestamp) }
            .reduce(0) { $0 + $1.milliliters }
    }

    private var hydrationCard: some View {
        HydrationCard(consumedMl: todayWaterMl, goalMl: goals.waterGoal) { amount in
            modelContext.insert(WaterEntry(milliliters: amount))
            HealthKitExporter.shared.exportWater(milliliters: amount, date: .now)
            SyncService.shared.syncNow()
        }
    }

    // MARK: Datos de la semana

    private var weekDays: [WeeklyBars.Day] {
        let calendar = Calendar.current
        let letters = ["D", "L", "M", "M", "J", "V", "S"] // weekday 1...7
        return (0..<7).reversed().map { offset in
            let date = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -offset, to: .now) ?? .now)
            let kcal = allEntries
                .filter { calendar.isDate($0.timestamp, inSameDayAs: date) }
                .dailyTotals.kcal
            let weekday = calendar.component(.weekday, from: date)
            return WeeklyBars.Day(
                id: date,
                letter: letters[weekday - 1],
                kcal: kcal,
                isToday: calendar.isDateInToday(date)
            )
        }
    }

    private var weekAverage: Double {
        let values = weekDays.map(\.kcal).filter { $0 > 0 }
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private func delete(_ meal: MealGroup) {
        SyncService.shared.deleteRemoteMeal(meal.entries.first?.remoteMealID)
        for entry in meal.entries {
            modelContext.delete(entry)
        }
    }

    /// Comparte el estado del día con el widget (App Group) y refresca timelines.
    private func publishWidgetSnapshot() {
        WidgetSnapshot(
            kcal: totals.kcal, kcalGoal: goals.kcal,
            protein: totals.protein, proteinGoal: goals.protein,
            carbs: totals.carbs, carbsGoal: goals.carbs,
            fat: totals.fat, fatGoal: goals.fat,
            streak: streak, updated: .now
        ).save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func generateSummaryIfPossible() async {
        guard IntelligenceService.isSupported, !todayEntries.isEmpty else {
            summary = nil
            return
        }
        let lines = todayEntries.map { entry in
            "\(entry.name): \(Int(entry.calories)) kcal, \(Int(entry.proteinG)) g proteína"
        }
        summary = try? await IntelligenceService.dailySummary(meals: lines, totals: totals)
    }
}
