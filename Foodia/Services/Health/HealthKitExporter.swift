import Foundation
import HealthKit

/// Escribe kcal y macros en Apple Salud al guardar una comida.
/// Foodia es la fuente de verdad; Salud recibe copias (write-only).
@Observable
final class HealthKitExporter {
    static let shared = HealthKitExporter()

    private static let enabledKey = "healthSyncEnabled"
    private let store = HKHealthStore()

    var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey) }
    }

    private init() {
        isEnabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
    }

    private var types: [HKQuantityType] {
        [
            HKQuantityType(.dietaryEnergyConsumed),
            HKQuantityType(.dietaryProtein),
            HKQuantityType(.dietaryCarbohydrates),
            HKQuantityType(.dietaryFatTotal),
            HKQuantityType(.dietaryWater),
        ]
    }

    /// Pide permiso y activa el sync. Devuelve false si el usuario lo negó.
    func requestAndEnable() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        do {
            try await store.requestAuthorization(toShare: Set(types), read: [])
        } catch {
            return false
        }
        let authorized = types.allSatisfy {
            store.authorizationStatus(for: $0) == .sharingAuthorized
        }
        isEnabled = authorized
        return authorized
    }

    func disable() {
        isEnabled = false
    }

    /// Exporta una comida guardada. Silencioso ante errores: Salud nunca
    /// bloquea el guardado en Foodia.
    func export(macros: Macros, date: Date) {
        guard isEnabled, HKHealthStore.isHealthDataAvailable() else { return }
        let samples = [
            sample(.dietaryEnergyConsumed, value: macros.kcal, unit: .kilocalorie(), date: date),
            sample(.dietaryProtein, value: macros.protein, unit: .gram(), date: date),
            sample(.dietaryCarbohydrates, value: macros.carbs, unit: .gram(), date: date),
            sample(.dietaryFatTotal, value: macros.fat, unit: .gram(), date: date),
        ]
        store.save(samples) { @Sendable _, _ in }
    }

    /// Exporta un registro de agua a Salud.
    func exportWater(milliliters: Double, date: Date) {
        guard isEnabled, HKHealthStore.isHealthDataAvailable() else { return }
        let sample = sample(.dietaryWater, value: milliliters, unit: .literUnit(with: .milli), date: date)
        store.save(sample) { @Sendable _, _ in }
    }

    private func sample(
        _ identifier: HKQuantityTypeIdentifier,
        value: Double,
        unit: HKUnit,
        date: Date
    ) -> HKQuantitySample {
        HKQuantitySample(
            type: HKQuantityType(identifier),
            quantity: HKQuantity(unit: unit, doubleValue: value),
            start: date,
            end: date
        )
    }
}
