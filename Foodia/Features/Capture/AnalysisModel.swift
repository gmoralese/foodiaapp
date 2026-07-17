import MLXLMCommon
import SwiftData
import UIKit

@Observable
final class AnalysisModel {
    enum Phase: Equatable {
        case preparingModel
        case analyzing
        case done
        case failed(String)
    }

    enum Engine: Equatable {
        case vision
        case vlm
        case cloud

        var displayName: String {
            switch self {
            case .vision: String(localized: "Apple Vision (clasificador)")
            case .vlm: String(localized: "Modelo local (\(VLMModelManager.displayName))")
            case .cloud: String(localized: "Nube (Gemini Flash)")
            }
        }

        var systemImage: String {
            switch self {
            case .vision: "eye"
            case .vlm: "brain"
            case .cloud: "cloud"
            }
        }
    }

    /// Un componente del plato en los flujos multi-componente, editable por el usuario.
    struct Component: Identifiable, Hashable {
        let id = UUID()
        var rawName: String
        var food: FoodItem?
        var grams: Double
        /// Macros por 100 g estimados por el backend, para alimentos fuera de la base local.
        var remotePer100g: Macros?
        /// Categoría estimada por el backend (para el ícono si no hay match local).
        var remoteCategory: FoodCategory?

        var effectivePer100g: Macros? {
            food?.per100g ?? remotePer100g
        }

        var lucideIcon: String {
            food?.lucideIcon ?? (remoteCategory ?? .dish).lucideId
        }
    }

    /// nil en el registro por voz/texto (sin foto).
    let image: UIImage?
    /// Descripción de la comida cuando no hay foto.
    let mealDescription: String?
    private let database: NutritionDatabase

    private(set) var phase: Phase = .analyzing
    private(set) var engine: Engine = .vision
    private(set) var note: String?

    // Flujo Vision (un solo alimento, chips de candidatos)
    private(set) var matches: [FoodMatch] = []
    private(set) var rawCandidates: [FoodCandidate] = []
    private(set) var selectedFood: FoodItem?
    var grams: Double = 100

    // Flujo VLM (múltiples componentes)
    var components: [Component] = []

    /// Categoría elegida por el usuario; arranca con la sugerencia por hora.
    var mealType: MealType = .inferred(from: .now)
    /// Contexto opcional del usuario (dictado o escrito) para afinar el análisis.
    var userContext: String = ""
    /// Evita que la vista relance el análisis si ya corrió (p. ej. desde la cámara).
    private(set) var hasAnalyzed = false
    /// Contexto con el que se corrió el último análisis (para saber si cambió).
    private(set) var analyzedContext: String = ""

    var canReanalyze: Bool {
        phase == .done
            && trimmedContext != analyzedContext
            && !trimmedContext.isEmpty
    }

    private var trimmedContext: String {
        userContext.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    init(image: UIImage, database: NutritionDatabase = .shared) {
        self.image = image
        self.mealDescription = nil
        self.database = database
    }

    /// Registro sin foto: la descripción (dictada o escrita) es la entrada.
    init(description: String, database: NutritionDatabase = .shared) {
        self.image = nil
        self.mealDescription = description
        self.database = database
    }

    var canSave: Bool {
        components.contains { $0.effectivePer100g != nil }
    }

    var totalMacros: Macros? {
        let scaled = components.compactMap { component in
            component.effectivePer100g?.scaled(by: component.grams / 100)
        }
        guard !scaled.isEmpty else { return nil }
        return scaled.reduce(Macros()) { $0 + $1 }
    }

    func analyze() async {
        hasAnalyzed = true
        guard let image else {
            await analyzeDescriptionOnly()
            return
        }
        analyzedContext = trimmedContext
        let context = trimmedContext.isEmpty ? nil : trimmedContext
        let preference = EnginePreference.current
        if preference == .cloud || preference == .auto {
            if let remote = RemoteFoodRecognizer() {
                engine = .cloud
                phase = .analyzing
                do {
                    apply(recognized: try await remote.recognize(in: image, context: context))
                    phase = .done
                    return
                } catch {
                    guard !Task.isCancelled else { return }
                    if preference == .cloud {
                        // Nube estricta: error visible con opciones, sin fallback silencioso.
                        phase = .failed(String(localized: "El motor Nube necesita internet y no pudimos llegar. Tu foto está a salvo: puedes reintentar o analizarla aquí mismo con el motor Local."))
                        return
                    }
                    note = String(localized: "Sin conexión con la nube — analicé con el motor de tu iPhone.")
                }
            } else if preference == .cloud {
                phase = .failed(String(localized: "El backend no está configurado en este build."))
                return
            }
        }
        await analyzeLocally(context: context)
    }

    /// Registro sin foto: nube primero, VLM local texto-only como fallback.
    private func analyzeDescriptionOnly() async {
        let description = [mealDescription, trimmedContext.isEmpty ? nil : trimmedContext]
            .compactMap { $0 }
            .joined(separator: ". ")
        analyzedContext = trimmedContext
        phase = .analyzing
        if let remote = RemoteFoodRecognizer() {
            engine = .cloud
            do {
                apply(recognized: try await remote.recognize(description: description))
                phase = .done
                return
            } catch {
                guard !Task.isCancelled else { return }
                note = String(localized: "Sin conexión con la nube — usé el modelo de tu iPhone.")
            }
        }
        let manager = VLMModelManager.shared
        if manager.container != nil || manager.isDownloaded {
            engine = .vlm
            phase = .preparingModel
            await manager.prepare()
            if let container = manager.container {
                phase = .analyzing
                do {
                    let recognizer = VLMFoodRecognizer(container: container)
                    apply(recognized: try await recognizer.recognize(description: description))
                    phase = .done
                    return
                } catch {
                    guard !Task.isCancelled else { return }
                }
            }
        }
        phase = .failed(String(localized: "Para registrar sin foto se necesita conexión o el modelo local descargado."))
    }

    /// Fuerza el análisis local (opción del estado de error de la cámara).
    func analyzeWithLocalEngine() async {
        note = nil
        let context = trimmedContext.isEmpty ? nil : trimmedContext
        await analyzeLocally(context: context)
    }

    /// Repite el análisis con el contexto actual del usuario.
    func reanalyze() async {
        note = nil
        await analyze()
    }

    private func analyzeLocally(context: String? = nil) async {
        let manager = VLMModelManager.shared
        if manager.container != nil || manager.isDownloaded {
            engine = .vlm
            phase = .preparingModel
            await manager.prepare()
            if let container = manager.container {
                await analyzeWithVLM(container, context: context)
                return
            }
            note = String(localized: "No se pudo cargar el modelo local; usé Apple Vision.")
        }
        engine = .vision
        await analyzeWithVision()
    }

    private func analyzeWithVLM(_ container: MLXLMCommon.ModelContainer, context: String? = nil) async {
        // Estos caminos siempre parten de una foto; el flujo sin foto va aparte.
        guard let image else { return }
        phase = .analyzing
        do {
            let recognizer = VLMFoodRecognizer(container: container)
            apply(recognized: try await recognizer.recognize(in: image, context: context))
            if components.isEmpty {
                note = String(localized: "El modelo no detectó comida; prueba con Vision o agrega componentes a mano.")
            }
            phase = .done
        } catch {
            note = String(localized: "El modelo local falló en esta foto; usé Apple Vision.")
            engine = .vision
            await analyzeWithVision()
        }
    }

    private func apply(recognized: [RecognizedComponent]) {
        components = recognized.map { item in
            let food = database.bestMatch(forName: item.name)
            let grams = item.grams ?? food?.defaultGrams ?? 100
            return Component(
                rawName: item.displayName ?? item.name,
                food: food,
                grams: min(1000, max(5, grams)),
                remotePer100g: item.per100g,
                remoteCategory: item.category
            )
        }
    }

    private func analyzeWithVision() async {
        guard let image else { return }
        phase = .analyzing
        do {
            let recognizer = VisionFoodRecognizer()
            let candidates = try await recognizer.recognize(in: image)
            rawCandidates = Array(candidates.prefix(4))
            matches = Array(database.matches(for: candidates).prefix(6))
            if let best = matches.first {
                select(best.food)
            }
            phase = .done
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    // MARK: Flujo Vision (un solo alimento; alimenta la misma lista de componentes)

    func select(_ food: FoodItem) {
        selectedFood = food
        grams = food.defaultGrams
        components = [Component(rawName: "", food: food, grams: food.defaultGrams)]
    }

    // MARK: Flujo VLM

    func assign(_ food: FoodItem, toComponentWith id: Component.ID) {
        guard let index = components.firstIndex(where: { $0.id == id }) else { return }
        components[index].food = food
        if components[index].grams == 100 || components[index].rawName.isEmpty {
            components[index].grams = food.defaultGrams
        }
    }

    func addComponent(with food: FoodItem) {
        components.append(Component(rawName: "", food: food, grams: food.defaultGrams))
    }

    func removeComponent(with id: Component.ID) {
        components.removeAll { $0.id == id }
    }

    // MARK: Guardado

    func save(in context: SwiftData.ModelContext) {
        let photoFilename = image.flatMap { try? PhotoStore.save($0) }
        let group = UUID()
        for component in components {
            guard let per100g = component.effectivePer100g else { continue }
            context.insert(makeEntry(
                name: component.food?.localizedName ?? component.rawName,
                emoji: component.food?.emoji ?? "🍽️",
                icon: component.lucideIcon,
                grams: component.grams,
                macros: per100g.scaled(by: component.grams / 100),
                photo: photoFilename,
                group: group,
                type: mealType
            ))
        }
        if let totals = totalMacros {
            HealthKitExporter.shared.export(macros: totals, date: .now)
        }
        SyncService.shared.syncNow()
    }

    private var engineRaw: String {
        switch engine {
        case .vision: "vision"
        case .vlm: "vlm"
        case .cloud: "cloud"
        }
    }

    private func makeEntry(
        name: String, emoji: String, icon: String, grams: Double,
        macros: Macros, photo: String?, group: UUID?, type: MealType
    ) -> MealEntry {
        MealEntry(
            timestamp: .now,
            name: name,
            emoji: emoji,
            grams: grams,
            calories: macros.kcal,
            proteinG: macros.protein,
            carbsG: macros.carbs,
            fatG: macros.fat,
            photoFilename: photo,
            confirmedByUser: true,
            mealGroupID: group,
            mealType: type.rawValue,
            icon: icon,
            engine: engineRaw
        )
    }
}
