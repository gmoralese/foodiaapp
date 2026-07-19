import Foundation

/// Un vínculo activo con un nutricionista (respuesta del backend).
struct NutritionistLink: Decodable, Identifiable, Hashable {
    let id: UUID
    let professionalId: UUID
    let professionalName: String
    let linkedAt: Date?
}

/// Preview de una invitación antes de aceptarla (quién invita).
struct InvitePreview: Decodable, Hashable {
    let code: String
    let professionalName: String
    let expiresAt: Date
}

/// Motivo por el que falló vincular un código, derivado del status HTTP del
/// backend. La vista lo traduce a un mensaje localizado.
enum ProfessionalLinkError: Error, Equatable {
    case notFound // 404: código inexistente
    case expired // 410: venció o ya no está disponible
    case alreadyLinked // 409: ya hay vínculo con ese profesional / código usado
    case selfCode // 422: es tu propio código
    case network // conexión u otro error

    /// Mapea el status HTTP a un motivo de dominio (lógica pura, testeable).
    init(status: Int) {
        switch status {
        case 404: self = .notFound
        case 410: self = .expired
        case 409: self = .alreadyLinked
        case 422: self = .selfCode
        default: self = .network
        }
    }
}

/// Estados de la vista para vincular un nutricionista, como enum (una sola
/// fuente de verdad del flujo: ingresar → buscar → consentir → aceptar).
enum LinkSheetState: Equatable {
    case entering
    case searching
    case preview(InvitePreview)
    case accepting(InvitePreview)
    case failed(ProfessionalLinkError)
}

enum InviteCode {
    /// Normaliza el código que tipea el paciente: mayúsculas y solo
    /// alfanuméricos (el pro puede dictarlo con espacios o guiones). Espeja el
    /// `normalizeInviteCode` del backend para que ambos lados coincidan.
    static func normalize(_ raw: String) -> String {
        String(raw.uppercased().unicodeScalars.filter { scalar in
            CharacterSet.alphanumerics.contains(scalar)
        })
    }
}
