import GameContent
import GameDomain
import Testing

@Suite("İçerik kataloğu")
struct GameContentTests {
    @Test("Planlanan içerik hacmi ve kapsaması bulunur")
    func plannedContentCoverage() throws {
        let catalog = try DefaultContentRepository().load()

        #expect(catalog.vehicles.count == 12)
        #expect(catalog.faults.count == 30)
        #expect(catalog.customers.count == 20)
        #expect(catalog.shopLevels.count == 7)
        #expect(catalog.washLevels.count == 3)
        #expect(catalog.reviews.count >= 24)
        #expect(Set(catalog.faults.map(\.area)) == Set(SkillArea.allCases))
        #expect(Set(catalog.faults.map(\.repairGame)).count == catalog.faults.count)
        #expect(catalog.faults.allSatisfy { $0.complaintVariants.count >= 2 })
        #expect(catalog.customers.allSatisfy { $0.minimumExpertise >= 1 })
        #expect(catalog.faults.allSatisfy { $0.inspectionFindings.count >= 2 })
        #expect(SkillArea.allCases.allSatisfy { area in
            Set(catalog.faults.filter { $0.area == area }.map(\.requiredSkill)).count >= 3
        })
        #expect(catalog.shopLevels[1].facilities.contains(.periodicMaintenance))
        #expect(catalog.shopLevels[1].maxApprentices == 1)
        #expect(catalog.shopLevels[2].facilities.contains(.washBay))
        #expect(catalog.shopLevels[4].facilities.contains(.bodyPaintBooth))
        #expect(catalog.shopLevels[6].facilities.contains(.vehicleShowroom))
        #expect(catalog.shopLevels[6].capacity == 5)
        #expect(catalog.washLevels.map(\.id) == [1, 2, 3])
        #expect(catalog.washLevels[2].trustBonus == 3)
        #expect(catalog.balance.dailyRent + catalog.balance.dailyUtilities + catalog.balance.dailySupplies == catalog.balance.dailyExpense)
    }

    @Test("Tekrarlanan içerik kimliği reddedilir")
    func duplicateIdentifierFails() throws {
        let catalog = try DefaultContentRepository().load()
        let invalid = ContentCatalog(
            vehicles: catalog.vehicles + [catalog.vehicles[0]],
            faults: catalog.faults,
            customers: catalog.customers,
            reviews: catalog.reviews,
            shopLevels: catalog.shopLevels,
            washLevels: catalog.washLevels,
            balance: catalog.balance
        )

        #expect(throws: ContentError.self) {
            try ContentValidator.validate(invalid)
        }
    }
}
