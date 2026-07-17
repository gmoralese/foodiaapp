import CoreImage
import Foundation
import HuggingFace
import MLXHuggingFace
import MLXLMCommon
import MLXVLM
import Tokenizers

// Uso: FoodVLMHarness <ruta-imagen> [model-id]
let arguments = CommandLine.arguments
guard arguments.count >= 2 else {
    fatalError("Uso: FoodVLMHarness <imagen> [model-id]")
}
let imagePath = arguments[1]
let modelID = arguments.count > 2 ? arguments[2] : "mlx-community/Qwen2-VL-2B-Instruct-4bit"

// Mismo prompt que VLMFoodRecognizer en la app
let prompt = """
    List every distinct food or drink visible in this photo. Respond with ONLY a JSON array, \
    no markdown fences, no explanations. Each element must be exactly: \
    {"name": "<food name in English, 1-3 words>", "grams": <estimated weight in grams, integer>}. \
    List at most 8 items and never repeat an item. \
    Example: [{"name":"white rice","grams":150},{"name":"fried egg","grams":55}]
    """

guard let ciImage = CIImage(contentsOf: URL(fileURLWithPath: imagePath)) else {
    fatalError("No se pudo leer la imagen \(imagePath)")
}

print("Modelo: \(modelID)")
print("Cargando/descargando…")
let loadStart = Date()
let container = try await #huggingFaceLoadModelContainer(
    configuration: ModelConfiguration(id: modelID)
) { progress in
    print(String(format: "  descarga: %3.0f%%", progress.fractionCompleted * 100))
}
print(String(format: "Modelo listo en %.1f s", Date().timeIntervalSince(loadStart)))

var parameters = GenerateParameters()
parameters.maxTokens = 400
parameters.temperature = 0
parameters.repetitionPenalty = 1.15
let session = ChatSession(container, generateParameters: parameters)
let inferenceStart = Date()
let text = try await session.respond(to: prompt, image: .ciImage(ciImage))
print(String(format: "\n--- Respuesta cruda (%.1f s de inferencia):", Date().timeIntervalSince(inferenceStart)))
print(text)

// Mismo parser que la app
struct Item: Codable {
    let name: String
    let grams: Double?
}
var items: [Item] = []
if let start = text.firstIndex(of: "["),
   let end = text.lastIndex(of: "]"),
   start < end,
   let data = String(text[start...end]).data(using: .utf8),
   let decoded = try? JSONDecoder().decode([Item].self, from: data) {
    items = decoded
} else {
    for match in text.matches(of: #/\{[^{}]*\}/#) {
        if let data = String(match.0).data(using: .utf8),
           let item = try? JSONDecoder().decode(Item.self, from: data) {
            items.append(item)
        }
    }
}

var seen = Set<String>()
var result: [(String, Double?)] = []
for item in items {
    let name = item.name.trimmingCharacters(in: .whitespaces)
    guard !name.isEmpty, seen.insert(name.lowercased()).inserted else { continue }
    result.append((name, item.grams))
    if result.count >= 10 { break }
}

if result.isEmpty {
    print("\n⚠️ Sin componentes parseables")
    exit(1)
}
print("\n--- Componentes parseados (\(result.count)):")
for (name, grams) in result {
    print("  • \(name) — \(grams.map { "\(Int($0)) g" } ?? "sin estimación")")
}
