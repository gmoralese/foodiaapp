import LucideIcons
import SwiftUI
import WidgetKit

@main
struct FoodiaWidgetBundle: WidgetBundle {
    var body: some Widget {
        FoodiaTodayWidget()
    }
}

struct FoodiaTodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FoodiaTodayWidget", provider: Provider()) { entry in
            FoodiaWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.wBackground
                }
        }
        .configurationDisplayName("Hoy en Foodia")
        .description("Tus calorías, macros y racha del día.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Timeline

struct Entry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry {
        Entry(date: .now, snapshot: .demo)
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(Entry(date: .now, snapshot: current()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let now = Entry(date: .now, snapshot: current())
        // A medianoche el día arranca en cero (la racha se conserva).
        var entries = [now]
        if var snapshot = current(),
           let midnight = Calendar.current.date(
               byAdding: .day, value: 1,
               to: Calendar.current.startOfDay(for: .now)
           ) {
            snapshot.kcal = 0
            snapshot.protein = 0
            snapshot.carbs = 0
            snapshot.fat = 0
            entries.append(Entry(date: midnight, snapshot: snapshot))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func current() -> WidgetSnapshot? {
        guard var snapshot = WidgetSnapshot.load() else { return nil }
        if snapshot.isStale {
            snapshot.kcal = 0
            snapshot.protein = 0
            snapshot.carbs = 0
            snapshot.fat = 0
        }
        return snapshot
    }
}

extension WidgetSnapshot {
    static let demo = WidgetSnapshot(
        kcal: 1240, kcalGoal: 1900, protein: 82, proteinGoal: 150,
        carbs: 116, carbsGoal: 190, fat: 35, fatGoal: 55, streak: 5, updated: .now
    )
}

// MARK: - Vistas

struct FoodiaWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: Entry

    var body: some View {
        if let snapshot = entry.snapshot {
            switch family {
            case .systemMedium:
                MediumView(snapshot: snapshot)
            default:
                SmallView(snapshot: snapshot)
            }
        } else {
            VStack(spacing: 6) {
                WIcon(id: "salad", size: 26, tint: .wAccent)
                Text("Abre Foodia para empezar")
                    .font(.caption2)
                    .foregroundStyle(Color.wTextSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

private struct SmallView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(spacing: 6) {
            WidgetRing(consumed: snapshot.kcal, goal: snapshot.kcalGoal)
                .frame(width: 78, height: 78)
            if snapshot.streak >= 2 {
                HStack(spacing: 3) {
                    WIcon(id: "flame", size: 12, tint: .wCarb)
                    Text("\(snapshot.streak)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.wTextPrimary)
                        .monospacedDigit()
                }
            }
        }
    }
}

private struct MediumView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        HStack(spacing: 16) {
            WidgetRing(consumed: snapshot.kcal, goal: snapshot.kcalGoal)
                .frame(width: 92, height: 92)
            VStack(alignment: .leading, spacing: 8) {
                macroBar("P", snapshot.protein, snapshot.proteinGoal, .wAccent)
                macroBar("C", snapshot.carbs, snapshot.carbsGoal, .wCarb)
                macroBar("G", snapshot.fat, snapshot.fatGoal, .wFat)
                if snapshot.streak >= 2 {
                    HStack(spacing: 3) {
                        WIcon(id: "flame", size: 11, tint: .wCarb)
                        Text("\(snapshot.streak) días")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Color.wTextSecondary)
                    }
                }
            }
        }
    }

    private func macroBar(_ label: String, _ value: Double, _ goal: Double, _ color: Color) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.wTextSecondary)
                .frame(width: 12)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.wTrack)
                    Capsule()
                        .fill(color)
                        .frame(width: goal > 0 ? min(proxy.size.width * value / goal, proxy.size.width) : 0)
                }
            }
            .frame(height: 5)
            Text("\(Int(value))g")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.wTextPrimary)
                .monospacedDigit()
        }
    }
}

private struct WidgetRing: View {
    let consumed: Double
    let goal: Double

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(consumed / goal, 1)
    }

    var body: some View {
        ZStack {
            Circle().stroke(Color.wTrack, lineWidth: 8)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    consumed > goal ? Color.wCarb : .wAccent,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(Int(consumed))")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.wTextPrimary)
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                Text("kcal")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.wTextSecondary)
            }
        }
    }
}

/// Ícono Lucide tintado (versión del widget).
private struct WIcon: View {
    let id: String
    var size: CGFloat = 16
    var tint: Color

    var body: some View {
        if let image = UIImage(lucideId: id) {
            Image(uiImage: image)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .foregroundStyle(tint)
        }
    }
}

// MARK: - Colores (mismos tokens del design system, autónomos en la extensión)

private extension Color {
    static let wBackground = Color(light: 0xFBF9F4, dark: 0x161815)
    static let wTrack = Color(light: 0xE9E6DB, dark: 0x34372F)
    static let wAccent = Color(light: 0x2E9E5A, dark: 0x43C77B)
    static let wCarb = Color(light: 0xC7861E, dark: 0xE5A94E)
    static let wFat = Color(light: 0x3E7BC7, dark: 0x7FB1E8)
    static let wTextPrimary = Color(light: 0x1D1C17, dark: 0xF2F1EA)
    static let wTextSecondary = Color(light: 0x6E6C60, dark: 0xA6A499)

    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}
