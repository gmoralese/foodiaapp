import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Capa opcional de Apple Intelligence (Foundation Models, iOS 26+).
/// El modelo vive en el sistema operativo: no agrega peso a la app y corre
/// 100% on-device. Si el equipo no lo soporta, la app funciona igual sin esto.
enum IntelligenceService {
    static var isSupported: Bool {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *) else { return false }
        if case .available = SystemLanguageModel.default.availability {
            return true
        }
        #endif
        return false
    }

    static func dailySummary(meals: [String], totals: Macros) async throws -> String? {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *) else { return nil }
        let isEnglish = FoodLocale.appLanguage == "en"
        let session = LanguageModelSession(instructions: isEnglish
            ? """
            You are a friendly, concise nutrition assistant. Always reply in English, \
            at most TWO sentences, in plain text without any formatting (no asterisks, \
            bold or lists), and never invent data that is not in the user's message.
            """
            : """
            Eres un asistente de nutrición amable y conciso. Responde siempre en español \
            neutro, en DOS frases como máximo, en texto plano sin ningún formato (nada de \
            asteriscos, negritas ni listas), sin inventar datos que no estén en el mensaje.
            """)
        let prompt = isEnglish
            ? """
            What I ate today:
            \(meals.joined(separator: "\n"))

            Daily totals: \(Int(totals.kcal)) kcal, \(Int(totals.protein)) g protein, \
            \(Int(totals.carbs)) g carbs and \(Int(totals.fat)) g fat.

            Give me a mini summary of my day and one simple tip for tomorrow.
            """
            : """
            Esto comí hoy:
            \(meals.joined(separator: "\n"))

            Totales del día: \(Int(totals.kcal)) kcal, \(Int(totals.protein)) g de proteína, \
            \(Int(totals.carbs)) g de carbohidratos y \(Int(totals.fat)) g de grasas.

            Haz un mini resumen de mi día y dame un consejo simple para mañana.
            """
        let response = try await session.respond(to: prompt)
        return response.content
        #else
        return nil
        #endif
    }
}
