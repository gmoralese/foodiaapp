import Foundation
import SwiftData

/// Una medición corporal fechada: peso y/o medidas (todas opcionales).
/// Es un histórico para ver la evolución; espejo de `body_measurements` en el
/// backend. Sigue el patrón de sync de WaterEntry (`needsSync`/`remoteID`).
@Model
final class BodyMeasurement {
    var measuredAt: Date
    var weightKg: Double?
    var waistCm: Double?
    var hipCm: Double?
    var chestCm: Double?
    var armCm: Double?
    var thighCm: Double?
    var neckCm: Double?
    var bodyFatPct: Double?
    /// id del registro en el backend; nil = aún no sincronizado.
    var remoteID: UUID?
    /// Pendiente de subir al backend (default true: lo local se respalda).
    var needsSync: Bool = true

    init(
        measuredAt: Date = .now,
        weightKg: Double? = nil,
        waistCm: Double? = nil,
        hipCm: Double? = nil,
        chestCm: Double? = nil,
        armCm: Double? = nil,
        thighCm: Double? = nil,
        neckCm: Double? = nil,
        bodyFatPct: Double? = nil
    ) {
        self.measuredAt = measuredAt
        self.weightKg = weightKg
        self.waistCm = waistCm
        self.hipCm = hipCm
        self.chestCm = chestCm
        self.armCm = armCm
        self.thighCm = thighCm
        self.neckCm = neckCm
        self.bodyFatPct = bodyFatPct
    }
}
