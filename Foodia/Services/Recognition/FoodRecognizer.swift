import UIKit
import Vision

nonisolated struct FoodCandidate: Hashable, Sendable {
    let label: String
    let confidence: Double
}

nonisolated enum RecognitionError: LocalizedError {
    case invalidImage

    var errorDescription: String? {
        String(localized: "La imagen no se pudo procesar.")
    }
}

/// Abstracción del motor de reconocimiento: hoy es el clasificador integrado
/// de Vision; mañana puede ser un VLM descargable sin tocar el resto de la app.
nonisolated protocol FoodRecognizing: Sendable {
    func recognize(in image: UIImage) async throws -> [FoodCandidate]
}

nonisolated struct VisionFoodRecognizer: FoodRecognizing {
    func recognize(in image: UIImage) async throws -> [FoodCandidate] {
        guard let cgImage = image.cgImage else {
            throw RecognitionError.invalidImage
        }
        let request = ClassifyImageRequest()
        let observations = try await request.perform(on: cgImage)
        return observations
            .filter { $0.confidence > 0.05 }
            .map { FoodCandidate(label: $0.identifier, confidence: Double($0.confidence)) }
    }
}
