import Foundation
import SwiftData

/// Un registro de agua (un vaso, una botella…).
@Model
final class WaterEntry {
    var timestamp: Date
    var milliliters: Double
    /// id del registro en el backend; nil = aún no sincronizado.
    var remoteID: UUID?
    /// Pendiente de subir al backend (default true: lo local se respalda).
    var needsSync: Bool = true

    init(timestamp: Date = .now, milliliters: Double) {
        self.timestamp = timestamp
        self.milliliters = milliliters
    }
}
