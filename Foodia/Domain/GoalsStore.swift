import Foundation

/// Metas diarias y plan del usuario, persistidos en UserDefaults.
/// Fuente de verdad para el anillo/barras del dashboard y el sheet de Metas.
@Observable
final class GoalsStore {
    static let shared = GoalsStore()

    private static let goalsKey = "dailyGoals"
    private static let planNameKey = "planName"
    private static let profileKey = "userProfile"

    var goals: DailyGoals {
        didSet { persist(goals, key: Self.goalsKey) }
    }

    /// "Déficit moderado", "Personalizado", etc. — se muestra en Ajustes.
    var planName: String {
        didSet { UserDefaults.standard.set(planName, forKey: Self.planNameKey) }
    }

    var profile: UserProfile? {
        didSet { persist(profile, key: Self.profileKey) }
    }

    /// Notifica ediciones hechas por el usuario (apply/applyCustom), para que
    /// la capa de sync empuje el snapshot. Lo setea RootView al arrancar.
    var didChange: (() -> Void)?

    private init() {
        goals = Self.load(DailyGoals.self, key: Self.goalsKey) ?? .fallback
        planName = UserDefaults.standard.string(forKey: Self.planNameKey) ?? "Sugerido"
        profile = Self.load(UserProfile.self, key: Self.profileKey)
    }

    func apply(plan: PlanOption, profile: UserProfile) {
        self.profile = profile
        goals = plan.goals
        planName = plan.name
        didChange?()
    }

    /// El usuario editó los números a mano: el plan pasa a "Personalizado".
    func applyCustom(goals: DailyGoals) {
        self.goals = goals
        planName = "Personalizado"
        didChange?()
    }

    private func persist(_ value: (some Encodable)?, key: String) {
        guard let value, let data = try? JSONEncoder().encode(value) else {
            UserDefaults.standard.removeObject(forKey: key)
            return
        }
        UserDefaults.standard.set(data, forKey: key)
    }

    private static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
