import Foundation
import GameContent
import GameDomain
import GameLogic
import GamePersistence
import Testing

@Suite("Deterministik oyun motoru")
struct GameLogicTests {
    @Test("Aynı seed aynı müşteri tekliflerini üretir")
    func deterministicOffers() throws {
        let catalog = try DefaultContentRepository().load()
        var first = GameEngine(catalog: catalog, seed: 42)
        var second = GameEngine(catalog: catalog, seed: 42)

        try first.handle(.prepareDay)
        try second.handle(.prepareDay)

        #expect(first.state.offers == second.state.offers)
        #expect(first.state.randomSeed == second.state.randomSeed)
    }

    @Test("Müşteri işi baştan sona tamamlanır")
    func customerVerticalSlice() throws {
        let catalog = try DefaultContentRepository().load()
        var engine = GameEngine(catalog: catalog, seed: 7)
        try engine.handle(.prepareDay)
        let offer = try #require(engine.state.offers.first)

        try engine.handle(.acceptOffer(offer.id))
        try engine.handle(.diagnose(jobID: offer.id, faultID: offer.actualFaultID))
        try engine.handle(.setQuote(jobID: offer.id, strategy: .fair, hidePartQuality: false))
        try engine.handle(.buyPart(jobID: offer.id, quality: .aftermarket))
        #expect(engine.state.inventory.count == 1)
        let events = try engine.handle(.completeRepair(jobID: offer.id, performance: 100))

        #expect(engine.state.activeJobs.isEmpty)
        #expect(engine.state.inventory.isEmpty)
        #expect(engine.state.remainingSlots == 4)
        #expect(events.contains { if case .repairCompleted = $0 { true } else { false } })
        #expect(engine.state.reputation.craftsmanship > 10)
    }

    @Test("Geçersiz komut zaman tüketmez")
    func failedCommandIsAtomic() throws {
        let catalog = try DefaultContentRepository().load()
        var engine = GameEngine(catalog: catalog)
        let before = engine.state

        #expect(throws: GameRuleError.self) {
            try engine.handle(.diagnose(jobID: UUID(), faultID: catalog.faults[0].id))
        }
        #expect(engine.state.remainingSlots == before.remainingSlots)
        #expect(engine.state.revision == before.revision)
    }

    @Test("Yanlış teşhis oyuncuya yeniden deneme şansı verir")
    func diagnosisCanBeRetried() throws {
        let catalog = try DefaultContentRepository().load()
        var engine = GameEngine(catalog: catalog, seed: 17)
        try engine.handle(.prepareDay)
        let offer = try #require(engine.state.offers.first)
        let wrong = try #require(offer.suspectedFaultIDs.first { $0 != offer.actualFaultID })
        try engine.handle(.acceptOffer(offer.id))

        try engine.handle(.diagnose(jobID: offer.id, faultID: wrong))
        #expect(engine.state.activeJobs[0].stage == .awaitingDiagnosis)
        #expect(engine.state.remainingSlots == 7)

        try engine.handle(.diagnose(jobID: offer.id, faultID: offer.actualFaultID))
        #expect(engine.state.activeJobs[0].stage == .awaitingQuote)
        #expect(engine.state.remainingSlots == 6)
    }

    @Test("Dördüncü gün ihale açılır ve rakip üst sınırını aşmaz")
    func auctionRules() throws {
        let catalog = try DefaultContentRepository().load()
        var engine = GameEngine(catalog: catalog, seed: 99)
        try engine.handle(.grantPurchase(transactionID: "test-funds", cash: Money(minorUnits: 200_000_000), themeID: nil))
        try engine.handle(.prepareDay)
        for _ in 0..<3 { try engine.handle(.endDay) }
        let auction = try #require(engine.state.auction)
        let lot = try #require(auction.lots.first)

        try engine.handle(.placeAuctionBid(lotID: lot.id, amount: lot.currentBid + Money(minorUnits: 50_000)))
        try engine.handle(.advanceAuctionRound)
        let updated = try #require(engine.state.auction?.lots.first(where: { $0.id == lot.id }))
        #expect(updated.currentBid <= updated.competitorMaximum || updated.playerIsHighest)
    }

    @Test("Kriz oyunu bitirmez ve sonraki günler oynanabilir")
    func recoverableCrisis() throws {
        let catalog = try DefaultContentRepository().load()
        var engine = GameEngine(catalog: catalog)
        try engine.handle(.prepareDay)
        for _ in 0..<25 { try engine.handle(.endDay) }

        #expect(engine.state.cash < .zero)
        #expect(engine.state.day == 26)
        #expect(engine.state.offers.count == 3)

        let offer = try #require(engine.state.offers.first)
        try engine.handle(.acceptOffer(offer.id))
        try engine.handle(.diagnose(jobID: offer.id, faultID: offer.actualFaultID))
        try engine.handle(.setQuote(jobID: offer.id, strategy: .fair, hidePartQuality: false))
        try engine.handle(.buyPart(jobID: offer.id, quality: .used))
        #expect(engine.state.activeJobs[0].stage == .readyForRepair)
    }

    @Test("Aynı StoreKit işlemi yalnızca bir kez ödül verir")
    func purchaseIsIdempotent() throws {
        let catalog = try DefaultContentRepository().load()
        var engine = GameEngine(catalog: catalog)
        let before = engine.state.cash
        let cash = Money(minorUnits: 750_000)

        try engine.handle(.grantPurchase(transactionID: "tx-1", cash: cash, themeID: nil))
        try engine.handle(.grantPurchase(transactionID: "tx-1", cash: cash, themeID: nil))

        #expect(engine.state.cash == before + cash)
        #expect(engine.state.processedTransactionIDs == ["tx-1"])
    }

    @Test("Sürüm 1 kayıt envanter alanı olmadan sürüm 2'ye taşınır")
    func legacySaveMigration() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ototamir-migration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let catalog = try DefaultContentRepository().load()
        var legacy = GameState(startingCash: catalog.balance.startingCash, daySlots: 8)
        legacy.schemaVersion = 1
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let encoded = try encoder.encode(legacy)
        var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "inventory")
        let legacyData = try JSONSerialization.data(withJSONObject: object)
        try legacyData.write(to: directory.appendingPathComponent("ototamir-save.json"))

        let repository = JSONFileSaveRepository(directory: directory)
        let migrated = try #require(try await repository.load())
        #expect(migrated.schemaVersion == GameState.currentSchemaVersion)
        #expect(migrated.inventory.isEmpty)
    }
}
