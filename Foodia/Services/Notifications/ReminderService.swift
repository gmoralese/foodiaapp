import Foundation
import UserNotifications

/// Recordatorio diario local (20:30): registra tu comida y cuida tu racha.
@Observable
final class ReminderService {
    static let shared = ReminderService()

    private static let enabledKey = "dailyReminderEnabled"
    private static let identifier = "foodia.daily-reminder"

    var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey) }
    }

    private init() {
        isEnabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
    }

    /// Pide permiso y programa el recordatorio. Devuelve false si fue negado.
    func enable() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        guard granted else {
            isEnabled = false
            return false
        }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "¿Ya registraste tu comida?")
        content.body = String(localized: "Una foto y listo — no pierdas tu racha 🔥")
        content.sound = .default

        var components = DateComponents()
        components.hour = 20
        components.minute = 30
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: Self.identifier, content: content, trigger: trigger)
        try? await center.add(request)
        isEnabled = true
        return true
    }

    func disable() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.identifier])
        isEnabled = false
    }
}
