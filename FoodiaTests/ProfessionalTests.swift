import Testing

@testable import Foodia

@Suite("InviteCode.normalize — espeja el normalize del backend")
struct InviteCodeTests {
    @Test("pasa a mayúsculas y quita espacios, guiones y símbolos")
    func stripsAndUppercases() {
        #expect(InviteCode.normalize("  ab c9 x2 ") == "ABC9X2")
        #expect(InviteCode.normalize("abc2-3456") == "ABC23456")
        #expect(InviteCode.normalize("ABCD2345") == "ABCD2345")
    }

    @Test("queda vacío cuando no hay alfanuméricos")
    func emptyWhenNoAlphanumerics() {
        #expect(InviteCode.normalize("  -- ") == "")
    }
}

@Suite("ProfessionalLinkError — mapeo del status HTTP a motivo de dominio")
struct ProfessionalLinkErrorTests {
    @Test("cada status conocido mapea a su motivo")
    func mapsKnownStatuses() {
        #expect(ProfessionalLinkError(status: 404) == .notFound)
        #expect(ProfessionalLinkError(status: 410) == .expired)
        #expect(ProfessionalLinkError(status: 409) == .alreadyLinked)
        #expect(ProfessionalLinkError(status: 422) == .selfCode)
    }

    @Test("un status desconocido cae en network")
    func unknownFallsToNetwork() {
        #expect(ProfessionalLinkError(status: 500) == .network)
        #expect(ProfessionalLinkError(status: 401) == .network)
        #expect(ProfessionalLinkError(status: 200) == .network)
    }
}
