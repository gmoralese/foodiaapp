import Foundation
import Testing

@testable import Foodia

@Suite("RemoteMerge.latestNewWeight — peso del perfil desde mediciones nuevas")
struct LatestNewWeightTests {
    let older = Date(timeIntervalSince1970: 1_000)
    let newer = Date(timeIntervalSince1970: 2_000)

    @Test("toma el peso nuevo más reciente si supera al último conocido")
    func picksNewest() {
        let weight = RemoteMerge.latestNewWeight(
            fresh: [(older, 70), (newer, 72)],
            latestKnownWeightDate: Date(timeIntervalSince1970: 500)
        )
        #expect(weight == 72)
    }

    @Test("ignora los pesos nuevos que no son más recientes que el conocido")
    func ignoresOlderThanKnown() {
        let weight = RemoteMerge.latestNewWeight(
            fresh: [(older, 70)],
            latestKnownWeightDate: newer
        )
        #expect(weight == nil)
    }

    @Test("nil si ninguna medición nueva trae peso")
    func nilWhenNoWeight() {
        let weight = RemoteMerge.latestNewWeight(
            fresh: [(newer, nil)],
            latestKnownWeightDate: nil
        )
        #expect(weight == nil)
    }
}

@Suite("RemoteMerge.goalsDecision — last-write-wins de metas")
struct GoalsDecisionTests {
    let base = DailyGoals(kcal: 2000, protein: 150, carbs: 200, fat: 60, waterMl: 2500)
    let changed = DailyGoals(kcal: 1800, protein: 150, carbs: 160, fat: 60, waterMl: 2500)
    let t1 = Date(timeIntervalSince1970: 1_000)
    let t2 = Date(timeIntervalSince1970: 2_000)

    @Test("aplica las remotas si cambiaron después de lo conocido y difieren")
    func appliesWhenRemoteNewerAndDifferent() {
        let decision = RemoteMerge.goalsDecision(
            remoteGoals: changed, remotePlanName: "Personalizado",
            remoteUpdatedAt: t2, localGoals: base, lastKnownUpdatedAt: t1
        )
        #expect(decision == .applyRemote(changed, planName: "Personalizado"))
    }

    @Test("no cambia si las metas remotas son iguales a las locales")
    func keepsWhenEqual() {
        let decision = RemoteMerge.goalsDecision(
            remoteGoals: base, remotePlanName: nil,
            remoteUpdatedAt: t2, localGoals: base, lastKnownUpdatedAt: t1
        )
        #expect(decision == .keepLocal)
    }

    @Test("no cambia si el updatedAt remoto no es más nuevo que lo conocido")
    func keepsWhenNotNewer() {
        let decision = RemoteMerge.goalsDecision(
            remoteGoals: changed, remotePlanName: nil,
            remoteUpdatedAt: t1, localGoals: base, lastKnownUpdatedAt: t1
        )
        #expect(decision == .keepLocal)
    }

    @Test("el primer sync (sin base conocida) no avisa")
    func firstSyncKeepsLocal() {
        let decision = RemoteMerge.goalsDecision(
            remoteGoals: changed, remotePlanName: nil,
            remoteUpdatedAt: t2, localGoals: base, lastKnownUpdatedAt: nil
        )
        #expect(decision == .keepLocal)
    }
}
