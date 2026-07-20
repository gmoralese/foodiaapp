import Foundation

/// Reglas PURAS de fusión de datos remotos con lo local (sync). No tienen
/// efectos: deciden qué aplicar; el `SyncService` ejecuta la decisión. Se
/// extraen acá para poder testearlas sin SwiftData ni red.
nonisolated enum RemoteMerge {
    /// Peso a aplicar al perfil si entre las mediciones NUEVAS (las que trajo el
    /// sync y no teníamos) hay un peso más reciente que el último peso ya
    /// conocido localmente. Si no, nil. Así una medición de peso que registró el
    /// nutricionista actualiza el peso del perfil, igual que una propia.
    static func latestNewWeight(
        fresh: [(date: Date, weight: Double?)],
        latestKnownWeightDate: Date?
    ) -> Double? {
        let candidates = fresh.compactMap { item -> (date: Date, weight: Double)? in
            guard let weight = item.weight else { return nil }
            return (item.date, weight)
        }
        guard let newest = candidates.max(by: { $0.date < $1.date }) else { return nil }
        if let known = latestKnownWeightDate, newest.date <= known { return nil }
        return newest.weight
    }

    enum GoalsDecision: Equatable {
        case keepLocal
        case applyRemote(DailyGoals, planName: String?)
    }

    /// Last-write-wins por `updatedAt`: si el servidor cambió las metas después
    /// de lo último que este dispositivo conocía y difieren de las locales, se
    /// aplican las remotas (el nutricionista las ajustó desde el portal). El
    /// primer sync (lastKnown == nil) no avisa: solo se registra el updatedAt de
    /// base. Una edición local posterior del paciente vuelve a mandar y gana,
    /// porque al empujar se actualiza `lastKnown` con el nuevo updatedAt.
    static func goalsDecision(
        remoteGoals: DailyGoals,
        remotePlanName: String?,
        remoteUpdatedAt: Date,
        localGoals: DailyGoals,
        lastKnownUpdatedAt: Date?
    ) -> GoalsDecision {
        guard let lastKnown = lastKnownUpdatedAt else { return .keepLocal }
        if remoteUpdatedAt > lastKnown, remoteGoals != localGoals {
            return .applyRemote(remoteGoals, planName: remotePlanName)
        }
        return .keepLocal
    }
}
