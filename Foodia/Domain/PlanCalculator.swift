import Foundation

nonisolated struct DailyGoals: Codable, Equatable {
    var kcal: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    /// Opcional para no romper metas ya persistidas (default 2 L).
    var waterMl: Double?

    var waterGoal: Double { waterMl ?? 2000 }

    /// Metas por defecto hasta completar el onboarding (las del diseño).
    static let fallback = DailyGoals(kcal: 1900, protein: 150, carbs: 190, fat: 55, waterMl: 2000)
}

nonisolated struct PlanOption: Identifiable, Equatable {
    let id: String
    let name: String
    let subtitle: String
    let goals: DailyGoals
    let isRecommended: Bool
}

/// Cálculo de gasto y metas: Mifflin-St Jeor + factor de actividad + objetivo.
nonisolated enum PlanCalculator {
    static func bmr(for profile: UserProfile) -> Double {
        let base = 10 * profile.weightKg + 6.25 * profile.heightCm - 5 * Double(profile.age)
        let sexTerm: Double =
            switch profile.sex {
            case .male: 5
            case .female: -161
            case .unspecified: -78 // promedio de ambos
            }
        return base + sexTerm
    }

    static func tdee(for profile: UserProfile) -> Double {
        bmr(for: profile) * profile.activity.factor
    }

    /// Opciones de plan para el paso "Plan sugerido" del onboarding.
    static func options(for profile: UserProfile) -> [PlanOption] {
        let maintenance = tdee(for: profile)
        switch profile.objective {
        case .deficit:
            return [
                option(String(localized: "Déficit suave"), String(localized: "−0,25 kg por semana"), profile, kcal: maintenance * 0.9),
                option(String(localized: "Déficit moderado"), String(localized: "−0,4 kg por semana, sin pasar hambre"), profile,
                       kcal: maintenance * 0.8, recommended: true),
                option(String(localized: "Déficit intenso"), String(localized: "−0,6 kg por semana"), profile, kcal: maintenance * 0.7),
            ]
        case .maintenance:
            return [option(String(localized: "Mantenimiento"), String(localized: "Sostener tu peso y comer mejor"), profile,
                           kcal: maintenance, recommended: true)]
        case .surplus:
            return [
                option(String(localized: "Volumen limpio"), String(localized: "+0,2 kg por semana"), profile,
                       kcal: maintenance * 1.1, recommended: true),
                option(String(localized: "Volumen agresivo"), String(localized: "+0,4 kg por semana"), profile, kcal: maintenance * 1.2),
            ]
        case .medical:
            return [option(String(localized: "Plan personalizado"), String(localized: "Carga los números de tu profesional"), profile,
                           kcal: maintenance, recommended: true)]
        }
    }

    private static func option(
        _ name: String, _ subtitle: String, _ profile: UserProfile,
        kcal: Double, recommended: Bool = false
    ) -> PlanOption {
        PlanOption(
            id: name,
            name: name,
            subtitle: subtitle,
            goals: goals(for: profile, kcal: kcal),
            isRecommended: recommended
        )
    }

    /// Reparto de macros: proteína por kg (más si entrena fuerza), grasa por kg,
    /// el resto en carbohidratos.
    static func goals(for profile: UserProfile, kcal: Double) -> DailyGoals {
        let proteinPerKg = profile.sports.contains("Fuerza") ? 2.0 : 1.8
        let protein = profile.weightKg * proteinPerKg
        let fat = profile.weightKg * 0.8
        let remainingKcal = max(0, kcal - protein * 4 - fat * 9)
        let carbs = remainingKcal / 4
        return DailyGoals(
            kcal: (kcal / 50).rounded() * 50,
            protein: (protein / 5).rounded() * 5,
            carbs: (carbs / 5).rounded() * 5,
            fat: (fat / 5).rounded() * 5
        )
    }
}
