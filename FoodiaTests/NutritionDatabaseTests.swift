import Foundation
import Testing

@testable import Foodia

/// `bestMatch` es una tabla canónica: solo devuelve un alimento local cuando el
/// nombre coincide EXACTAMENTE. Todo lo demás lo resuelve el modelo. Estos tests
/// fijan que un plato con nombre propio ya no sea secuestrado por un ingrediente
/// suelto que comparte una palabra (el bug "ají de gallina" → "puré de papas").
@Suite("NutritionDatabase.bestMatch — solo match exacto")
struct NutritionDatabaseBestMatchTests {
    /// Catálogo mínimo con las trampas del bug real: alimentos cuyo nombre o
    /// alias comparten una palabra con platos que el usuario podría registrar.
    let db = NutritionDatabase(foods: [
        food(id: "mashed_potatoes", name: "Puré de papas", aliases: ["mashed potatoes", "pure de papas"]),
        food(id: "white_rice", name: "Arroz blanco", aliases: ["white rice", "arroz blanco"]),
        food(id: "milk", name: "Leche", aliases: ["milk", "leche"]),
        food(id: "corn", name: "Mazorca", aliases: ["corn", "choclo"]),
    ])

    @Test("un plato con nombre propio no cae en un ingrediente que comparte una palabra")
    func namedDishFallsThrough() {
        // Compartían "de" con "puré de papas"; con scoring difuso ganaban.
        #expect(db.bestMatch(forName: "aji de gallina") == nil)
        #expect(db.bestMatch(forName: "carne de vacuno") == nil)
        // Comparte "choclo" con "Mazorca", pero es un plato distinto.
        #expect(db.bestMatch(forName: "pastel de choclo") == nil)
        // "leche de almendras" no es leche de vaca: no debe tomar sus macros.
        #expect(db.bestMatch(forName: "leche de almendras") == nil)
    }

    @Test("un ingrediente genérico curado sí se resuelve contra la base")
    func curatedIngredientMatches() {
        #expect(db.bestMatch(forName: "white rice")?.id == "white_rice")
        #expect(db.bestMatch(forName: "mashed potatoes")?.id == "mashed_potatoes")
    }

    @Test("el match ignora acentos y mayúsculas")
    func matchIsDiacriticInsensitive() {
        #expect(db.bestMatch(forName: "Arroz Blanco")?.id == "white_rice")
        #expect(db.bestMatch(forName: "pure de papas")?.id == "mashed_potatoes")
    }

    @Test("una variante que no está textual cae al modelo en vez de forzar un match")
    func unlistedVariantFallsThrough() {
        // Trade-off deliberado: preferimos el valor del modelo antes que un
        // match parcial difuso. "white rice" sí matchea; "cooked white rice" no.
        #expect(db.bestMatch(forName: "cooked white rice") == nil)
    }

    @Test("nombre vacío o en blanco no matchea nada")
    func blankNameIsNil() {
        #expect(db.bestMatch(forName: "") == nil)
        #expect(db.bestMatch(forName: "   ") == nil)
    }
}

private func food(id: String, name: String, aliases: [String]) -> FoodItem {
    FoodItem(
        id: id,
        name: name,
        nameEn: nil,
        emoji: "🍽️",
        category: .dish,
        icon: nil,
        aliases: aliases,
        kcal: 100,
        protein: 5,
        carbs: 10,
        fat: 3,
        defaultGrams: 100
    )
}
