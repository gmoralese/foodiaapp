import Testing

@testable import Foodia

@Suite("VLMFoodRecognizer.parse — JSON tolerante")
struct VLMParseTests {
    @Test("un array JSON limpio se parsea a componentes con gramos")
    func cleanArray() throws {
        let components = try VLMFoodRecognizer.parse(
            #"[{"name":"white rice","grams":150},{"name":"fried egg","grams":55}]"#
        )
        #expect(components.count == 2)
        #expect(components[0].name == "white rice")
        #expect(components[0].grams == 150)
        #expect(components[1].name == "fried egg")
        #expect(components[1].grams == 55)
    }

    @Test("ignora el texto alrededor del array")
    func extractsArrayFromSurroundingText() throws {
        let components = try VLMFoodRecognizer.parse(
            #"Here is the meal: [{"name":"toast","grams":30}] hope it helps!"#
        )
        #expect(components.count == 1)
        #expect(components[0].name == "toast")
    }

    @Test("tolera las cercas de markdown ```json")
    func handlesMarkdownFences() throws {
        let text = "```json\n[{\"name\":\"pasta\",\"grams\":200}]\n```"
        let components = try VLMFoodRecognizer.parse(text)
        #expect(components.count == 1)
        #expect(components[0].name == "pasta")
    }

    @Test("recupera objetos sueltos cuando faltan los corchetes del array")
    func recoversLooseObjectsWithoutBrackets() throws {
        let components = try VLMFoodRecognizer.parse(
            #"{"name":"apple","grams":100} then {"name":"banana","grams":120}"#
        )
        #expect(components.count == 2)
        #expect(components.map(\.name) == ["apple", "banana"])
    }

    @Test("deduplica por nombre sin distinguir mayúsculas y conserva el primero")
    func deduplicatesByLowercasedName() throws {
        let components = try VLMFoodRecognizer.parse(
            #"[{"name":"Rice","grams":100},{"name":"rice","grams":50}]"#
        )
        #expect(components.count == 1)
        #expect(components[0].name == "Rice")
        #expect(components[0].grams == 100)
    }

    @Test("recorta el nombre y descarta los vacíos")
    func trimsNamesAndDropsBlanks() throws {
        let components = try VLMFoodRecognizer.parse(
            #"[{"name":"  ","grams":5},{"name":" toast ","grams":30}]"#
        )
        #expect(components.count == 1)
        #expect(components[0].name == "toast")
    }

    @Test("los gramos son opcionales")
    func gramsAreOptional() throws {
        let components = try VLMFoodRecognizer.parse(#"[{"name":"water"}]"#)
        #expect(components.count == 1)
        #expect(components[0].grams == nil)
    }

    @Test("tope de 10 componentes aunque el modelo devuelva más")
    func capsAtTenComponents() throws {
        let objects = (0..<12).map { #"{"name":"food\#($0)","grams":10}"# }.joined(separator: ",")
        let components = try VLMFoodRecognizer.parse("[\(objects)]")
        #expect(components.count == 10)
    }

    @Test("una respuesta sin JSON lanza error")
    func throwsWhenNoJSON() {
        #expect(throws: VLMRecognitionError.self) {
            try VLMFoodRecognizer.parse("Sorry, I can't help with that.")
        }
    }

    @Test("un array vacío lanza error")
    func throwsOnEmptyArray() {
        #expect(throws: VLMRecognitionError.self) {
            try VLMFoodRecognizer.parse("[]")
        }
    }
}
