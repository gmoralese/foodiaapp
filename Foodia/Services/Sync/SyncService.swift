import Foundation
import SwiftData

/// Sincroniza SwiftData con el backend, best-effort: la app siempre funciona
/// offline con sus datos locales y esto empuja/baja cambios cuando hay red.
///
/// - Push: entradas con `needsSync` (comidas y agua) y borrados pendientes.
/// - Backfill: primera sesión en un dispositivo → baja TODO el historial
///   paginado (keyset) del backend hacia SwiftData.
/// - Perfil/metas: snapshot debounced tras cambios del usuario.
final class SyncService {
    static let shared = SyncService()

    private var container: ModelContainer?
    private var syncing = false
    private var profilePushTask: Task<Void, Never>?

    private let deletionsKey = "pendingMealDeletions"

    private init() {}

    func configure(container: ModelContainer) {
        self.container = container
    }

    // MARK: Disparadores

    func syncNow() {
        Task { await sync() }
    }

    /// Marca el meal remoto para borrar (si ya estaba sincronizado) y sincroniza.
    func deleteRemoteMeal(_ remoteMealID: UUID?) {
        guard let remoteMealID else { return }
        var pending = UserDefaults.standard.stringArray(forKey: deletionsKey) ?? []
        pending.append(remoteMealID.uuidString)
        UserDefaults.standard.set(pending, forKey: deletionsKey)
        syncNow()
    }

    /// Empuja el estado actual de metas/perfil/país, con debounce para las
    /// ediciones en vivo (steppers de Metas).
    func pushProfileSnapshot() {
        profilePushTask?.cancel()
        profilePushTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled, AuthService.shared.session != nil else { return }
            let goals = GoalsStore.shared.goals
            let profile = GoalsStore.shared.profile
            var patch = ProfilePatch(
                planName: GoalsStore.shared.planName,
                goalKcal: goals.kcal,
                goalProteinG: goals.protein,
                goalCarbsG: goals.carbs,
                goalFatG: goals.fat,
                goalWaterMl: goals.waterMl,
                foodCountry: FoodLocale.country
            )
            if let profile {
                patch.sex = profile.sex.rawValue
                patch.age = profile.age
                patch.weightKg = profile.weightKg
                patch.heightCm = profile.heightCm
                patch.activity = profile.activity.rawValue
                patch.sports = profile.sports
                patch.objective = profile.objective.rawValue
            }
            try? await BackendClient.shared.updateProfile(patch)
        }
    }

    /// Borra todo el contenido remoto del usuario (comidas y agua), para
    /// "Eliminar todos mis datos". Best-effort.
    func wipeRemote() {
        UserDefaults.standard.removeObject(forKey: deletionsKey)
        Task {
            while let page = try? await BackendClient.shared.meals(cursor: nil),
                  !page.items.isEmpty {
                for meal in page.items {
                    try? await BackendClient.shared.deleteMeal(id: meal.id)
                }
                if page.nextCursor == nil { break }
            }
            while let page = try? await BackendClient.shared.water(cursor: nil),
                  !page.items.isEmpty {
                for entry in page.items {
                    try? await BackendClient.shared.deleteWater(id: entry.id)
                }
                if page.nextCursor == nil { break }
            }
        }
    }

    // MARK: Ciclo de sync

    private func sync() async {
        guard !syncing, let container, AuthService.shared.session != nil else { return }
        syncing = true
        defer { syncing = false }
        let context = container.mainContext
        await drainDeletions()
        await backfillIfNeeded(context)
        await pushPendingMeals(context)
        await pushPendingWater(context)
    }

    private func drainDeletions() async {
        var pending = UserDefaults.standard.stringArray(forKey: deletionsKey) ?? []
        guard !pending.isEmpty else { return }
        for raw in pending {
            guard let id = UUID(uuidString: raw) else {
                pending.removeAll { $0 == raw }
                continue
            }
            do {
                try await BackendClient.shared.deleteMeal(id: id)
                pending.removeAll { $0 == raw }
            } catch {
                break // sin red: se reintenta en el próximo sync
            }
        }
        UserDefaults.standard.set(pending, forKey: deletionsKey)
    }

    // MARK: Push de pendientes

    private func pushPendingMeals(_ context: ModelContext) async {
        let descriptor = FetchDescriptor<MealEntry>(
            predicate: #Predicate { $0.needsSync }
        )
        guard let entries = try? context.fetch(descriptor), !entries.isEmpty else { return }

        // Un POST por grupo (los componentes de una misma foto van juntos).
        var groups: [UUID: [MealEntry]] = [:]
        for entry in entries {
            groups[entry.mealGroupID ?? UUID(), default: []].append(entry)
        }
        for group in groups.values {
            guard let first = group.first else { continue }
            do {
                let photoPath = await uploadPhotoIfNeeded(first.photoFilename)
                let payload = CreateMealPayload(
                    mealType: first.mealType
                        ?? MealType.inferred(from: first.timestamp).rawValue,
                    eatenAt: first.timestamp,
                    engine: first.engine,
                    photoPath: photoPath,
                    components: group.map { entry in
                        ComponentPayload(
                            name: entry.name,
                            icon: entry.icon,
                            emoji: entry.emoji,
                            grams: entry.grams,
                            kcal: entry.calories,
                            proteinG: entry.proteinG,
                            carbsG: entry.carbsG,
                            fatG: entry.fatG
                        )
                    }
                )
                let remote = try await BackendClient.shared.createMeal(payload)
                for entry in group {
                    entry.remoteMealID = remote.id
                    entry.needsSync = false
                }
            } catch {
                continue // queda pendiente para el próximo sync
            }
        }
        try? context.save()
    }

    private func uploadPhotoIfNeeded(_ filename: String?) async -> String? {
        guard let filename,
              let image = PhotoStore.load(filename),
              let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        return try? await AuthService.shared.uploadMealPhoto(data, filename: filename)
    }

    private func pushPendingWater(_ context: ModelContext) async {
        let descriptor = FetchDescriptor<WaterEntry>(
            predicate: #Predicate { $0.needsSync }
        )
        guard let entries = try? context.fetch(descriptor), !entries.isEmpty else { return }
        for entry in entries {
            do {
                let remote = try await BackendClient.shared.createWater(
                    milliliters: entry.milliliters,
                    loggedAt: entry.timestamp
                )
                entry.remoteID = remote.id
                entry.needsSync = false
            } catch {
                break
            }
        }
        try? context.save()
    }

    // MARK: Backfill (restauración en dispositivo nuevo)

    private func backfillIfNeeded(_ context: ModelContext) async {
        guard let userID = AuthService.shared.userID else { return }
        let flag = "didBackfill-\(userID.uuidString)"
        guard !UserDefaults.standard.bool(forKey: flag) else { return }

        do {
            let knownMeals = Set(
                (try context.fetch(FetchDescriptor<MealEntry>()))
                    .compactMap(\.remoteMealID)
            )
            var cursor: String?
            repeat {
                let page = try await BackendClient.shared.meals(cursor: cursor)
                for meal in page.items where !knownMeals.contains(meal.id) {
                    for component in meal.components {
                        context.insert(MealEntry(
                            timestamp: meal.eatenAt,
                            name: component.name,
                            emoji: component.emoji ?? "🍽️",
                            grams: component.grams,
                            calories: component.kcal,
                            proteinG: component.proteinG,
                            carbsG: component.carbsG,
                            fatG: component.fatG,
                            photoFilename: nil,
                            confirmedByUser: true,
                            mealGroupID: meal.id,
                            mealType: meal.mealType,
                            icon: component.icon,
                            remoteMealID: meal.id,
                            needsSync: false,
                            engine: meal.engine
                        ))
                    }
                }
                cursor = page.nextCursor
            } while cursor != nil

            let knownWater = Set(
                (try context.fetch(FetchDescriptor<WaterEntry>()))
                    .compactMap(\.remoteID)
            )
            cursor = nil
            repeat {
                let page = try await BackendClient.shared.water(cursor: cursor)
                for entry in page.items where !knownWater.contains(entry.id) {
                    let local = WaterEntry(
                        timestamp: entry.loggedAt,
                        milliliters: entry.milliliters
                    )
                    local.remoteID = entry.id
                    local.needsSync = false
                    context.insert(local)
                }
                cursor = page.nextCursor
            } while cursor != nil

            try? context.save()
            UserDefaults.standard.set(true, forKey: flag)
        } catch {
            // Sin red: se reintenta en el próximo sync (el flag queda en false).
        }
    }
}
