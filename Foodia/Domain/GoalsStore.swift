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

    /// true cuando el sync aplicó metas que cambió el nutricionista desde el
    /// portal (E4). Hoy y Metas muestran un aviso; se baja al descartarlo.
    /// Transitorio (no se persiste).
    var goalsUpdatedByPro = false

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

    /// Actualiza el peso actual del perfil (lo usa Mifflin-St Jeor) y sincroniza.
    /// NO recalcula las metas: eso lo decide el usuario (recalcGoalsFromProfile).
    func updateWeight(_ kg: Double) {
        guard var profile else { return }
        profile.weightKg = kg
        self.profile = profile
        didChange?()
    }

    /// Recalcula las metas con el perfil actual (peso + objetivo), tomando el
    /// plan recomendado de Mifflin-St Jeor. El usuario lo dispara a mano.
    /// Devuelve false si no hay perfil (onboarding incompleto).
    @discardableResult
    func recalcGoalsFromProfile() -> Bool {
        guard let profile else { return false }
        let options = PlanCalculator.options(for: profile)
        guard let plan = options.first(where: \.isRecommended) ?? options.first else {
            return false
        }
        apply(plan: plan, profile: profile)
        return true
    }

    /// Actualiza el nombre del perfil y sincroniza.
    func updateName(_ name: String?) {
        guard var profile else { return }
        profile.name = name
        self.profile = profile
        didChange?()
    }

    /// Actualiza el path del avatar (tras subirlo) y sincroniza.
    func updateAvatarPath(_ path: String?) {
        guard var profile else { return }
        profile.avatarPath = path
        self.profile = profile
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
