import Foundation
import SwiftData

@Model
final class MealEntry {
    var timestamp: Date
    var name: String
    var emoji: String
    var grams: Double
    var calories: Double
    var proteinG: Double
    var carbsG: Double
    var fatG: Double
    var photoFilename: String?
    var confirmedByUser: Bool
    /// Agrupa los componentes registrados desde una misma foto.
    var mealGroupID: UUID?
    /// Categoría elegida por el usuario (raw de MealType). nil en datos viejos.
    var mealType: String?
    /// Ícono Lucide del alimento (raw). nil en datos viejos → emoji legacy.
    var icon: String?
    /// id del meal en el backend; compartido por todas las filas del grupo.
    var remoteMealID: UUID?
    /// Pendiente de subir al backend (default true: lo local se respalda).
    var needsSync: Bool = true
    /// Motor que analizó (vision/vlm/cloud); viaja en el payload de sync.
    var engine: String?

    init(
        timestamp: Date,
        name: String,
        emoji: String,
        grams: Double,
        calories: Double,
        proteinG: Double,
        carbsG: Double,
        fatG: Double,
        photoFilename: String?,
        confirmedByUser: Bool,
        mealGroupID: UUID? = nil,
        mealType: String? = nil,
        icon: String? = nil,
        remoteMealID: UUID? = nil,
        needsSync: Bool = true,
        engine: String? = nil
    ) {
        self.timestamp = timestamp
        self.name = name
        self.emoji = emoji
        self.grams = grams
        self.calories = calories
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.photoFilename = photoFilename
        self.confirmedByUser = confirmedByUser
        self.mealGroupID = mealGroupID
        self.mealType = mealType
        self.icon = icon
        self.remoteMealID = remoteMealID
        self.needsSync = needsSync
        self.engine = engine
    }

    var macros: Macros {
        Macros(kcal: calories, protein: proteinG, carbs: carbsG, fat: fatG)
    }
}
