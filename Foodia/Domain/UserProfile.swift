import Foundation

nonisolated enum Sex: String, Codable, CaseIterable {
    case male
    case female
    case unspecified

    var title: String {
        switch self {
        case .male: String(localized: "Hombre")
        case .female: String(localized: "Mujer")
        case .unspecified: String(localized: "Prefiero no decir")
        }
    }
}

nonisolated enum ActivityLevel: String, Codable, CaseIterable {
    case sedentary
    case light
    case moderate
    case high

    var title: String {
        switch self {
        case .sedentary: String(localized: "Casi nada")
        case .light: String(localized: "1–2 veces por semana")
        case .moderate: String(localized: "3–5 veces por semana")
        case .high: String(localized: "6 o más veces por semana")
        }
    }

    var subtitle: String {
        switch self {
        case .sedentary: String(localized: "Trabajo sentado, poco movimiento")
        case .light: String(localized: "Algo de ejercicio, caminatas")
        case .moderate: String(localized: "Entrenas varias veces por semana")
        case .high: String(localized: "Entrenamiento intenso casi diario")
        }
    }

    var factor: Double {
        switch self {
        case .sedentary: 1.2
        case .light: 1.375
        case .moderate: 1.55
        case .high: 1.725
        }
    }
}

nonisolated enum GoalObjective: String, Codable, CaseIterable {
    case deficit
    case maintenance
    case surplus
    case medical

    var lucideId: String {
        switch self {
        case .deficit: "trending-down"
        case .maintenance: "scale"
        case .surplus: "trending-up"
        case .medical: "stethoscope"
        }
    }

    var title: String {
        switch self {
        case .deficit: String(localized: "Déficit calórico")
        case .maintenance: String(localized: "Mantenimiento")
        case .surplus: String(localized: "Volumen")
        case .medical: String(localized: "Indicación médica")
        }
    }

    var subtitle: String {
        switch self {
        case .deficit: String(localized: "Bajar grasa manteniendo el músculo")
        case .maintenance: String(localized: "Sostener tu peso y comer mejor")
        case .surplus: String(localized: "Ganar músculo con superávit controlado")
        case .medical: String(localized: "Sigues un plan de un profesional: cárgalo a mano")
        }
    }
}

nonisolated struct UserProfile: Codable, Equatable {
    var sex: Sex = .unspecified
    var age: Int = 28
    var weightKg: Double = 72
    var heightCm: Double = 175
    var activity: ActivityLevel = .moderate
    var sports: [String] = []
    var objective: GoalObjective = .deficit
    var name: String? = nil
    var avatarPath: String? = nil
}
