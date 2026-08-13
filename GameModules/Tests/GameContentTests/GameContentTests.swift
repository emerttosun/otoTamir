import GameContent
import GameDomain
import Testing

@Suite("İçerik kataloğu")
struct GameContentTests {
    @Test("Planlanan içerik hacmi ve kapsaması bulunur")
    func plannedContentCoverage() throws {
        let catalog = try DefaultContentRepository().load()

        #expect(catalog.vehicles.count == 6)
        #expect(catalog.faults.count == 12)
        #expect(catalog.customers.count == 10)
        #expect(catalog.shopLevels.count == 3)
        #expect(Set(catalog.faults.map(\.area)) == Set(SkillArea.allCases))
        #expect(Set(catalog.faults.map(\.repairGame)) == Set(RepairGameKind.allCases))
        #expect(catalog.balance.daySlots == 8)
    }

    @Test("Tekrarlanan içerik kimliği reddedilir")
    func duplicateIdentifierFails() throws {
        let catalog = try DefaultContentRepository().load()
        let invalid = ContentCatalog(
            vehicles: catalog.vehicles + [catalog.vehicles[0]],
            faults: catalog.faults,
            customers: catalog.customers,
            shopLevels: catalog.shopLevels,
            balance: catalog.balance
        )

        #expect(throws: ContentError.self) {
            try ContentValidator.validate(invalid)
        }
    }
}

