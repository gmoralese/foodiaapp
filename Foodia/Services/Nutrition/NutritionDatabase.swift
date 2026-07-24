import Foundation

nonisolated struct Macros: Hashable, Sendable {
    var kcal: Double = 0
    var protein: Double = 0
    var carbs: Double = 0
    var fat: Double = 0

    func scaled(by factor: Double) -> Macros {
        Macros(kcal: kcal * factor, protein: protein * factor, carbs: carbs * factor, fat: fat * factor)
    }

    static func + (lhs: Macros, rhs: Macros) -> Macros {
        Macros(
            kcal: lhs.kcal + rhs.kcal,
            protein: lhs.protein + rhs.protein,
            carbs: lhs.carbs + rhs.carbs,
            fat: lhs.fat + rhs.fat
        )
    }
}

/// Alimento de la base local. Los valores nutricionales son por 100 g.
/// `aliases` son las etiquetas (en inglés, normalizadas) que puede devolver Vision.
nonisolated struct FoodItem: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let nameEn: String?
    let emoji: String
    let category: FoodCategory?
    let icon: String?
    let aliases: [String]
    let kcal: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let defaultGrams: Double

    var per100g: Macros {
        Macros(kcal: kcal, protein: protein, carbs: carbs, fat: fat)
    }

    /// Nombre para la UI según el idioma de la app.
    var localizedName: String {
        FoodLocale.appLanguage == "en" ? (nameEn ?? name) : name
    }

    /// Ícono Lucide: el específico si existe, si no el de la categoría.
    var lucideIcon: String {
        icon ?? (category ?? .dish).lucideId
    }
}

nonisolated struct FoodMatch: Identifiable, Hashable, Sendable {
    let food: FoodItem
    let confidence: Double

    var id: String { food.id }
}

/// Base nutricional local (bundled, solo lectura). Sin red, sin servidor.
nonisolated final class NutritionDatabase: Sendable {
    static let shared = NutritionDatabase()

    let foods: [FoodItem]

    init() {
        guard let url = Bundle.main.url(forResource: "nutrition", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode(FoodList.self, from: data) else {
            assertionFailure("nutrition.json faltante o inválido en el bundle")
            foods = []
            return
        }
        foods = list.foods
    }

    /// Inicializador con catálogo explícito, para tests deterministas que no
    /// dependen del `nutrition.json` empaquetado.
    init(foods: [FoodItem]) {
        self.foods = foods
    }

    /// Cruza las etiquetas de Vision con la base local y devuelve los alimentos
    /// candidatos ordenados por confianza.
    func matches(for candidates: [FoodCandidate]) -> [FoodMatch] {
        var best: [String: FoodMatch] = [:]
        for candidate in candidates {
            let label = Self.normalize(candidate.label)
            guard !label.isEmpty else { continue }
            let labelWords = Set(label.split(separator: " ").map(String.init))
            for food in foods {
                let hit = food.aliases.contains { alias in
                    if alias == label { return true }
                    if labelWords.contains(alias) { return true }
                    return alias.split(separator: " ").map(String.init).contains(label)
                }
                guard hit else { continue }
                if let existing = best[food.id], existing.confidence >= candidate.confidence { continue }
                best[food.id] = FoodMatch(food: food, confidence: candidate.confidence)
            }
        }
        return best.values.sorted { $0.confidence > $1.confidence }
    }

    /// Alimento local cuyo nombre o alias coincide EXACTAMENTE con `rawName`
    /// (normalizado). Es una tabla canónica de ingredientes curados, no un
    /// matcher difuso: si el nombre no está tal cual, devuelve nil y el llamador
    /// conserva lo que estimó el modelo, que ya entiende de platos.
    ///
    /// Antes puntuaba por solapamiento de palabras y cualquier score > 0 ganaba,
    /// así que un plato como "ají de gallina" terminaba en "puré de papas" por
    /// compartir la palabra "de" (las stopwords eran solo en inglés). La decisión
    /// de qué es cada plato es del modelo; la base solo aporta valores fijos para
    /// los ingredientes genéricos que sí tiene catalogados.
    func bestMatch(forName rawName: String) -> FoodItem? {
        let name = Self.normalize(rawName)
        guard !name.isEmpty else { return nil }
        return foods.first { food in
            Self.normalize(food.name) == name
                || food.aliases.contains { Self.normalize($0) == name }
        }
    }

    /// Búsqueda manual por nombre en español o alias en inglés.
    func search(_ query: String) -> [FoodItem] {
        let q = Self.normalize(query)
        guard !q.isEmpty else {
            return foods.sorted { $0.name < $1.name }
        }
        return foods
            .filter { food in
                Self.normalize(food.name).contains(q) || food.aliases.contains { $0.contains(q) }
            }
            .sorted { $0.name < $1.name }
    }

    static func normalize(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US"))
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private nonisolated struct FoodList: Codable {
    let foods: [FoodItem]
}
