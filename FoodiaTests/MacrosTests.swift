import Testing

@testable import Foodia

@Suite("Macros")
struct MacrosTests {
    @Test("scaled multiplica cada macro por el factor")
    func scaledMultipliesEveryField() {
        let scaled = Macros(kcal: 100, protein: 10, carbs: 20, fat: 5).scaled(by: 2)
        #expect(scaled == Macros(kcal: 200, protein: 20, carbs: 40, fat: 10))
    }

    @Test("scaled con factor fraccionario re-escala hacia abajo")
    func scaledByHalf() {
        let scaled = Macros(kcal: 250, protein: 30, carbs: 40, fat: 10).scaled(by: 0.5)
        #expect(scaled == Macros(kcal: 125, protein: 15, carbs: 20, fat: 5))
    }

    @Test("per100g: escalar por 100/gramos es la conversión del motor Nube")
    func scaledForPer100gConversion() {
        // El backend manda macros de la porción; la app las lleva a por-100 g.
        let portion = Macros(kcal: 300, protein: 12, carbs: 45, fat: 8) // 150 g
        let per100 = portion.scaled(by: 100 / 150)
        #expect(per100.kcal == 200)
        #expect(per100.protein == 8)
        #expect(per100.carbs == 30)
        #expect(abs(per100.fat - 16.0 / 3.0) < 0.0001)
    }

    @Test("la suma agrega campo a campo")
    func additionSumsFields() {
        let a = Macros(kcal: 100, protein: 10, carbs: 20, fat: 5)
        let b = Macros(kcal: 50, protein: 5, carbs: 10, fat: 2)
        #expect(a + b == Macros(kcal: 150, protein: 15, carbs: 30, fat: 7))
    }

    @Test("Macros() es el elemento neutro de la suma")
    func zeroIsAdditiveIdentity() {
        let a = Macros(kcal: 100, protein: 10, carbs: 20, fat: 5)
        #expect(a + Macros() == a)
        #expect(Macros() == Macros(kcal: 0, protein: 0, carbs: 0, fat: 0))
    }
}
