import Charts
import SwiftData
import SwiftUI

/// Historial: tendencia semanal expandida + días navegables.
struct HistoryView: View {
    var onCapture: () -> Void

    @Query(sort: \MealEntry.timestamp, order: .reverse) private var allEntries: [MealEntry]
    @State private var selectedMonth: Date = Calendar.current.startOfDay(for: .now)

    private var goals: DailyGoals { GoalsStore.shared.goals }

    private struct DaySummary: Identifiable {
        let date: Date
        let entries: [MealEntry]
        var id: Date { date }
        var totals: Macros { entries.dailyTotals }
        var mealCount: Int { MealGroup.group(entries).count }
        /// Íconos de las comidas del día (máx. 4 distintos).
        var icons: [String] {
            var seen = Set<String>()
            return Array(entries.compactMap { entry -> String? in
                let icon = entry.icon ?? FoodCategory.dish.lucideId
                return seen.insert(icon).inserted ? icon : nil
            }.prefix(4))
        }
    }

    private var months: [Date] {
        let calendar = Calendar.current
        let all = Set(allEntries.map {
            calendar.date(from: calendar.dateComponents([.year, .month], from: $0.timestamp)) ?? $0.timestamp
        })
        return all.sorted(by: >)
    }

    private var days: [DaySummary] {
        let calendar = Calendar.current
        let filtered = allEntries.filter {
            calendar.isDate($0.timestamp, equalTo: selectedMonth, toGranularity: .month)
        }
        return Dictionary(grouping: filtered) { calendar.startOfDay(for: $0.timestamp) }
            .map { DaySummary(date: $0.key, entries: $0.value) }
            .sorted { $0.date > $1.date }
    }

    /// Últimos 7 días con registro dentro del mes elegido (para el chart).
    private var chartDays: [DaySummary] {
        Array(days.prefix(7)).sorted { $0.date < $1.date }
    }

    var body: some View {
        NavigationStack {
            Group {
                if allEntries.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            screenTitle
                            EmptyStateView(
                            icon: "book-open",
                            title: "Tu diario arranca hoy",
                            message: "Cuando registres tu primera comida, aquí verás tus días y tu tendencia semanal.",
                            ctaTitle: "Registrar mi primera comida",
                                action: onCapture
                            )
                            .padding(.top, 60)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                    }
                } else {
                    content
                }
            }
            .background(Color.dsBackground)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Date.self) { date in
                DayDetailView(date: date)
            }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                screenTitle
                monthPicker
                chartCard
                daysList
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
    }

    private var screenTitle: some View {
        Text("Historial")
            .font(.dsScreenTitle)
            .foregroundStyle(Color.dsTextPrimary)
    }

    private var monthPicker: some View {
        Menu {
            ForEach(months, id: \.self) { month in
                Button {
                    selectedMonth = month
                } label: {
                    Text(month, format: .dateTime.month(.wide).year())
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(selectedMonth, format: .dateTime.month(.wide))
                    .font(.dsRowTitle)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(Color.dsTextPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.dsInset, in: .capsule)
        }
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(weekRangeTitle)
                    .font(.dsSection)
                    .foregroundStyle(Color.dsTextPrimary)
                Spacer()
                Text("meta \(Int(goals.kcal)) kcal")
                    .font(.caption)
                    .foregroundStyle(Color.dsTextSecondary)
            }
            Chart {
                ForEach(chartDays) { day in
                    BarMark(
                        x: .value("Día", day.date, unit: .day),
                        y: .value("kcal", day.totals.kcal),
                        width: .fixed(16)
                    )
                    .foregroundStyle(day.totals.kcal > goals.kcal ? Color.dsBarOver : .dsBarMeta)
                    .cornerRadius(5)
                }
                RuleMark(y: .value("Meta", goals.kcal))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .foregroundStyle(Color.dsBorderStrong)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
                        .foregroundStyle(Color.dsTextTertiary)
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 130)
            legend
        }
        .padding(16)
        .background(Color.dsCard, in: .rect(cornerRadius: DSRadius.card, style: .continuous))
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendItem(color: .dsBarMeta, label: "En meta")
            legendItem(color: .dsBarOver, label: "Excedido")
            HStack(spacing: 5) {
                Rectangle()
                    .fill(Color.dsBorderStrong)
                    .frame(width: 14, height: 1.5)
                Text("Tu meta")
                    .font(.caption2)
                    .foregroundStyle(Color.dsTextSecondary)
            }
        }
    }

    private func legendItem(color: Color, label: LocalizedStringKey) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2.5)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.dsTextSecondary)
        }
    }

    private var weekRangeTitle: String {
        guard let first = chartDays.first?.date, let last = chartDays.last?.date else {
            return String(localized: "Esta semana")
        }
        let firstDay = Calendar.current.component(.day, from: first)
        let lastDay = Calendar.current.component(.day, from: last)
        return String(localized: "Semana del \(firstDay) al \(lastDay)")
    }

    private var daysList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Días")
                .font(.dsSection)
                .foregroundStyle(Color.dsTextPrimary)
            ForEach(days) { day in
                NavigationLink(value: day.date) {
                    dayRow(day)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func dayRow(_ day: DaySummary) -> some View {
        let over = day.totals.kcal > goals.kcal
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(dayTitle(day.date))
                    .font(.dsRowTitle)
                    .foregroundStyle(Color.dsTextPrimary)
                HStack(spacing: 5) {
                    ForEach(day.icons, id: \.self) { icon in
                        DSIcon(id: icon, size: 13, tint: .dsTextSecondary)
                    }
                    Text("· \(day.mealCount) comida\(day.mealCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(Color.dsTextSecondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("\(Int(day.totals.kcal)) kcal")
                    .font(.dsRowValue)
                    .foregroundStyle(over ? Color.dsOver : .dsGreenText)
                    .monospacedDigit()
                Text(over ? "+\(Int(day.totals.kcal - goals.kcal)) kcal" : "en meta ✓")
                    .font(.caption2)
                    .foregroundStyle(over ? Color.dsOver : .dsTextSecondary)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.dsBorderStrong)
        }
        .padding(12)
        .background(Color.dsCard, in: .rect(cornerRadius: DSRadius.card, style: .continuous))
    }

    private func dayTitle(_ date: Date) -> String {
        let formatted = date.formatted(.dateTime.weekday(.wide).day())
        if Calendar.current.isDateInToday(date) { return String(localized: "Hoy, \(formatted)") }
        if Calendar.current.isDateInYesterday(date) { return String(localized: "Ayer, \(formatted)") }
        return formatted.prefix(1).uppercased() + formatted.dropFirst()
    }
}
