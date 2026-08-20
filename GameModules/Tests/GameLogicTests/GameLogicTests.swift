import Foundation
import GameContent
import GameDomain
import GameLogic
import GamePersistence
import Testing

@Suite("Deterministik oyun motoru")
struct GameLogicTests {
    @Test("Aynı seed ve zaman aynı müşteri akışını üretir")
    func deterministicOffers() throws {
        let catalog = try DefaultContentRepository().load()
        var first = GameEngine(catalog: catalog, seed: 42)
        var second = GameEngine(catalog: catalog, seed: 42)

        try first.handle(.prepareWorld)
        try second.handle(.prepareWorld)
        try first.handle(.advanceTime(minutes: 240))
        try second.handle(.advanceTime(minutes: 240))

        #expect(first.state.offers == second.state.offers)
        #expect(first.state.randomSeed == second.state.randomSeed)
    }

    @Test("Müşteri işi kontrol, parça, fiyat, tamir ve teslim sırasıyla tamamlanır")
    func customerVerticalSlice() throws {
        let catalog = try DefaultContentRepository().load()
        let fault = catalog.faults[0]
        var engine = makeFaultEngine(catalog: catalog, fault: fault)
        let offer = try #require(engine.state.offers.first)
        let startCash = engine.state.cash

        try engine.handle(.acceptOffer(offer.id))
        for kind in Array(fault.inspectionFindings.keys.prefix(2)) {
            try engine.handle(.performInspection(jobID: offer.id, kind: kind))
        }
        #expect(engine.state.activeJobs[0].findings.count == 2)
        try engine.handle(.diagnose(jobID: offer.id, faultID: fault.id))
        #expect(engine.state.activeJobs[0].stage == .awaitingPart)

        try engine.handle(.buyPart(jobID: offer.id, quality: .aftermarket))
        #expect(engine.state.inventory.count == 1)
        try engine.handle(.setPrice(jobID: offer.id, strategy: .fair, hidePartQuality: false))
        #expect(engine.state.activeJobs[0].stage == .readyForRepair)
        try engine.handle(.completeRepair(jobID: offer.id, performance: 100))
        #expect(engine.state.activeJobs[0].stage == .awaitingDelivery)
        let events = try engine.handle(.deliverVehicle(jobID: offer.id))

        #expect(engine.state.activeJobs.isEmpty)
        #expect(engine.state.inventory.isEmpty)
        #expect(engine.state.cash > startCash)
        #expect(events.contains { if case .priceSettled = $0 { true } else { false } })
        #expect(engine.state.expertise[fault.area, default: SkillProgress()].experience > 0)
    }

    @Test("Anlaşılan müşteri fiyatı teslimde kesin tahsil edilir")
    func selectedCustomerPriceIsCollectedExactly() throws {
        let sample = CustomerQuoteBreakdown(
            partCost: Money(minorUnits: 100_000),
            laborCost: Money(minorUnits: 200_000)
        )
        #expect(sample.amount(for: .affordable).minorUnits == 255_000)
        #expect(sample.amount(for: .fair).minorUnits == 300_000)
        #expect(sample.amount(for: .high).minorUnits == 405_000)
        #expect(sample.amount(for: .excessive).minorUnits == 540_000)

        let catalog = try DefaultContentRepository().load()
        let fault = catalog.faults[0]
        var engine = makeFaultEngine(catalog: catalog, fault: fault)
        let offer = try #require(engine.state.offers.first)

        try engine.handle(.acceptOffer(offer.id))
        for kind in Array(fault.inspectionFindings.keys.prefix(2)) {
            try engine.handle(.performInspection(jobID: offer.id, kind: kind))
        }
        try engine.handle(.diagnose(jobID: offer.id, faultID: fault.id))
        try engine.handle(.buyPart(jobID: offer.id, quality: .aftermarket))

        let job = try #require(engine.state.activeJobs.first)
        let inventory = try #require(engine.state.inventory.first)
        let breakdown = CustomerPricingRules.quote(
            partCost: inventory.purchasePrice,
            for: job,
            catalog: catalog
        )
        let expectedPayment = breakdown.amount(for: .fair)
        try engine.handle(.setPrice(jobID: offer.id, strategy: .fair, hidePartQuality: false))
        try engine.handle(.completeRepair(jobID: offer.id, performance: 100))
        let cashBeforeDelivery = engine.state.cash

        let events = try engine.handle(.deliverVehicle(jobID: offer.id))

        #expect(engine.state.cash == cashBeforeDelivery + expectedPayment)
        #expect(events.contains {
            if case let .priceSettled(amount, _) = $0 { amount == expectedPayment } else { false }
        })
    }

    @Test("Fiyat bilgisi yüksek müşteri karşı teklif verir ve orta yolda anlaşır")
    func knowledgeableCustomerNegotiatesBeforeRepair() throws {
        let catalog = try DefaultContentRepository().load()
        let fault = catalog.faults[0]
        let dealer = try #require(catalog.customer(id: "dealer_cemil"))
        var state = GameState(
            startingCash: catalog.balance.startingCash,
            daySlots: catalog.balance.daySlots,
            randomSeed: 7
        )
        let offer = CustomerOffer(
            id: UUID(),
            customerID: dealer.id,
            vehicleID: catalog.vehicles[0].id,
            actualFaultID: fault.id,
            suspectedFaultIDs: [fault.id],
            complaint: fault.complaint
        )
        state.offers = [offer]
        var engine = GameEngine(state: state, catalog: catalog)
        try engine.handle(.acceptOffer(offer.id))
        for kind in Array(fault.inspectionFindings.keys.prefix(2)) {
            try engine.handle(.performInspection(jobID: offer.id, kind: kind))
        }
        try engine.handle(.diagnose(jobID: offer.id, faultID: fault.id))
        try engine.handle(.buyPart(jobID: offer.id, quality: .aftermarket))

        var pricingState = engine.state
        pricingState.randomSeed = 1
        engine = GameEngine(state: pricingState, catalog: catalog)
        let cashBeforeQuote = engine.state.cash
        let events = try engine.handle(
            .setPrice(jobID: offer.id, strategy: .excessive, hidePartQuality: false)
        )
        let negotiatingJob = try #require(engine.state.activeJobs.first)

        #expect(negotiatingJob.stage == .negotiating)
        #expect(negotiatingJob.customerCounterOffer != nil)
        #expect(engine.state.cash == cashBeforeQuote)
        #expect(events.contains { if case .customerCountered = $0 { true } else { false } })

        try engine.handle(.respondToCustomerOffer(jobID: offer.id, response: .meetHalfway))
        #expect(engine.state.activeJobs[0].stage == .readyForRepair)
        #expect(engine.state.activeJobs[0].quote == CustomerNegotiationRules.halfway(
            askingPrice: try #require(negotiatingJob.initialQuote),
            counterOffer: try #require(negotiatingJob.customerCounterOffer)
        ))
        let suspicionBeforeDelivery = engine.state.reputation.suspicion
        try engine.handle(.completeRepair(jobID: offer.id, performance: 95))
        let deliveryEvents = try engine.handle(.deliverVehicle(jobID: offer.id))
        #expect(engine.state.reputation.suspicion == suspicionBeforeDelivery)
        #expect(deliveryEvents.filter { if case .reviewReceived = $0 { true } else { false } }.count <= 1)
    }

    @Test("Teknik bilgisi yüksek müşteri kötü işçiliği daha kolay fark eder")
    func technicalKnowledgeAffectsCustomerEvaluation() throws {
        let catalog = try DefaultContentRepository().load()
        let fault = catalog.faults[0]
        let offer = CustomerOffer(
            id: UUID(),
            customerID: "new_driver_emre",
            vehicleID: catalog.vehicles[0].id,
            actualFaultID: fault.id,
            suspectedFaultIDs: [fault.id],
            complaint: fault.complaint
        )
        var job = RepairJob(offer: offer)
        let normalTotal = Money(minorUnits: 500_000)
        job.initialQuote = normalTotal
        job.quote = normalTotal
        let lowKnowledge = try #require(catalog.customer(id: "new_driver_emre"))
        let highKnowledge = try #require(catalog.customer(id: "enthusiast_arda"))
        var lowRandom = SeededRandomSource(seed: 1)
        var highRandom = SeededRandomSource(seed: 1)

        let lowEvaluation = CustomerExperienceRules.evaluate(
            job: job,
            customer: lowKnowledge,
            workmanship: .poor,
            partQuality: .aftermarket,
            normalTotal: normalTotal,
            random: &lowRandom
        )
        let highEvaluation = CustomerExperienceRules.evaluate(
            job: job,
            customer: highKnowledge,
            workmanship: .poor,
            partQuality: .aftermarket,
            normalTotal: normalTotal,
            random: &highRandom
        )

        #expect(!lowEvaluation.detectedPoorWork)
        #expect(highEvaluation.detectedPoorWork)
        #expect(highEvaluation.stars < lowEvaluation.stars)
    }

    @Test("Yıkama kötü işçiliği iyi müşteri deneyimine çeviremez")
    func washingIsOnlyAFinalTouch() throws {
        let catalog = try DefaultContentRepository().load()
        let customer = try #require(catalog.customer(id: "enthusiast_arda"))
        let fault = catalog.faults[0]
        let offer = CustomerOffer(
            id: UUID(),
            customerID: customer.id,
            vehicleID: catalog.vehicles[0].id,
            actualFaultID: fault.id,
            suspectedFaultIDs: [fault.id],
            complaint: fault.complaint
        )
        var job = RepairJob(offer: offer)
        let normalTotal = Money(minorUnits: 500_000)
        job.initialQuote = normalTotal
        job.quote = normalTotal
        job.isWashed = true
        var random = SeededRandomSource(seed: 1)

        let evaluation = CustomerExperienceRules.evaluate(
            job: job,
            customer: customer,
            workmanship: .poor,
            partQuality: .aftermarket,
            normalTotal: normalTotal,
            random: &random
        )

        #expect(evaluation.detectedPoorWork)
        #expect(evaluation.stars <= 2)
        #expect(evaluation.tone == .negative)
    }

    @Test("Fiyatta diretilince ayrılan müşterinin parçası yüzde on kesintiyle iade edilir")
    func rejectedPriceReturnsPartWithDeduction() throws {
        let catalog = try DefaultContentRepository().load()
        let fault = catalog.faults[0]
        let dealer = try #require(catalog.customer(id: "dealer_cemil"))
        let offer = CustomerOffer(
            id: UUID(),
            customerID: dealer.id,
            vehicleID: catalog.vehicles[0].id,
            actualFaultID: fault.id,
            suspectedFaultIDs: [fault.id],
            complaint: fault.complaint
        )
        var state = GameState(
            startingCash: catalog.balance.startingCash,
            daySlots: catalog.balance.daySlots,
            randomSeed: 1
        )
        state.offers = [offer]
        var engine = GameEngine(state: state, catalog: catalog)

        try engine.handle(.acceptOffer(offer.id))
        for kind in Array(fault.inspectionFindings.keys.prefix(2)) {
            try engine.handle(.performInspection(jobID: offer.id, kind: kind))
        }
        try engine.handle(.diagnose(jobID: offer.id, faultID: fault.id))
        try engine.handle(.buyPart(jobID: offer.id, quality: .aftermarket))
        try engine.handle(.setPrice(jobID: offer.id, strategy: .excessive, hidePartQuality: false))
        let purchasePrice = try #require(engine.state.inventory.first?.purchasePrice)
        let deduction = Money(minorUnits: purchasePrice.minorUnits / 10)
        let refund = purchasePrice - deduction
        let cashBeforeResponse = engine.state.cash

        var rejectionState = engine.state
        rejectionState.randomSeed = 1
        engine = GameEngine(state: rejectionState, catalog: catalog)
        let events = try engine.handle(.respondToCustomerOffer(jobID: offer.id, response: .insist))

        #expect(engine.state.cash == cashBeforeResponse + refund)
        #expect(engine.state.activeJobs.isEmpty)
        #expect(engine.state.inventory.isEmpty)
        #expect(engine.state.financeEntries.suffix(2).map(\.category) == [.partReturn, .partReturnLoss])
        #expect(events.contains(.customerWalkedAway(partRefund: refund, deduction: deduction)))
    }

    @Test("Geçersiz komut oyun zamanını tüketmez")
    func failedCommandIsAtomic() throws {
        let catalog = try DefaultContentRepository().load()
        var engine = GameEngine(catalog: catalog)
        let before = engine.state

        #expect(throws: GameRuleError.self) {
            try engine.handle(.diagnose(jobID: UUID(), faultID: catalog.faults[0].id))
        }
        #expect(engine.state.totalMinutes == before.totalMinutes)
        #expect(engine.state.revision == before.revision)
    }

    @Test("Yanlış teşhis oyun içi zaman kaybettirir ve yeniden denenebilir")
    func diagnosisCanBeRetried() throws {
        let catalog = try DefaultContentRepository().load()
        let fault = catalog.faults[0]
        let wrongFault = try #require(catalog.faults.first { $0.id != fault.id && $0.area == fault.area })
        var engine = makeFaultEngine(catalog: catalog, fault: fault, alternative: wrongFault)
        let offer = try #require(engine.state.offers.first)
        try engine.handle(.acceptOffer(offer.id))
        for kind in Array(fault.inspectionFindings.keys.prefix(2)) {
            try engine.handle(.performInspection(jobID: offer.id, kind: kind))
        }
        let before = engine.state.totalMinutes

        try engine.handle(.diagnose(jobID: offer.id, faultID: wrongFault.id))
        #expect(engine.state.activeJobs[0].stage == .awaitingDiagnosis)
        #expect(engine.state.totalMinutes == before + 20)

        try engine.handle(.diagnose(jobID: offer.id, faultID: fault.id))
        #expect(engine.state.activeJobs[0].stage == .awaitingPart)
    }

    @Test("Müşteriler sabit üçlü liste yerine zamanla gelir ve ayrılır")
    func dynamicCustomerFlow() throws {
        let catalog = try DefaultContentRepository().load()
        var engine = GameEngine(catalog: catalog, seed: 55)
        try engine.handle(.prepareWorld)
        #expect(engine.state.offers.count == 1)

        try engine.handle(.advanceTime(minutes: 240))
        #expect(engine.state.offers.count <= 3)
        #expect(engine.state.totalMinutes == 720)
    }

    @Test("Bekleyen müşteri hem gönderilebilir hem de süresi dolunca ayrılır")
    func customerCanBeDeclinedOrExpire() throws {
        let catalog = try DefaultContentRepository().load()
        var engine = GameEngine(catalog: catalog, seed: 91)
        try engine.handle(.prepareWorld)
        let declinedOffer = try #require(engine.state.offers.first)
        let beforeDecline = engine.state.totalMinutes

        let declineEvents = try engine.handle(.declineOffer(declinedOffer.id))

        #expect(!engine.state.offers.contains { $0.id == declinedOffer.id })
        #expect(engine.state.totalMinutes == beforeDecline + 15)
        #expect(declineEvents.contains(.customerLeft(declinedOffer.id)))

        let expiringID = UUID()
        var expiryState = GameState(
            startingCash: catalog.balance.startingCash,
            daySlots: catalog.balance.daySlots,
            randomSeed: 91
        )
        expiryState.offers = [CustomerOffer(
            id: expiringID,
            customerID: catalog.customers[0].id,
            vehicleID: catalog.vehicles[0].id,
            serviceKind: .faultRepair,
            actualFaultID: catalog.faults[0].id,
            suspectedFaultIDs: [catalog.faults[0].id],
            complaint: "Bekleme testi",
            arrivedAtMinute: expiryState.totalMinutes,
            expiresAtMinute: expiryState.totalMinutes + 10
        )]
        var expiryEngine = GameEngine(state: expiryState, catalog: catalog)

        let expiryEvents = try expiryEngine.handle(.advanceTime(minutes: 10))

        #expect(expiryEngine.state.offers.isEmpty)
        #expect(expiryEvents.contains(.customerLeft(expiringID)))
    }

    @Test("Uzmanlık ilerledikçe zor işler, yeni müşteriler ve araçlar açılır")
    func expertiseUnlocksContent() throws {
        let catalog = try DefaultContentRepository().load()
        var state = GameState(startingCash: catalog.balance.startingCash, daySlots: 8)

        let startingFaults = ProgressionRules.availableFaults(in: catalog, state: state)
        let startingCustomers = ProgressionRules.availableCustomers(in: catalog, state: state)
        let startingVehicleCount = ProgressionRules.unlockedVehicleCount(in: catalog, state: state)
        #expect(startingFaults.allSatisfy { $0.requiredSkill <= 1 })
        #expect(startingCustomers.allSatisfy { $0.minimumExpertise <= 1 })

        state.expertise[.engine] = SkillProgress(level: 5)
        state.skills[.engine] = 5
        state.shopLevel = 3

        let progressedFaults = ProgressionRules.availableFaults(in: catalog, state: state)
        let progressedCustomers = ProgressionRules.availableCustomers(in: catalog, state: state)
        #expect(progressedFaults.contains { $0.area == .engine && $0.requiredSkill == 5 })
        #expect(progressedFaults.filter { $0.area != .engine }.allSatisfy { $0.requiredSkill <= 1 })
        #expect(progressedCustomers.contains { $0.minimumExpertise == 4 })
        #expect(ProgressionRules.unlockedVehicleCount(in: catalog, state: state) > startingVehicleCount)
    }

    @Test("Yıllık bakım birden fazla mini oyun göreviyle tamamlanır")
    func periodicMaintenanceFlow() throws {
        let catalog = try DefaultContentRepository().load()
        var state = GameState(startingCash: catalog.balance.startingCash, daySlots: 8, randomSeed: 11)
        let id = UUID()
        state.offers = [CustomerOffer(
            id: id,
            customerID: catalog.customers[0].id,
            vehicleID: catalog.vehicles[0].id,
            serviceKind: .periodicMaintenance,
            actualFaultID: nil,
            suspectedFaultIDs: [],
            maintenanceTasks: [.oilAndFilter, .batteryTest, .tireCheck],
            complaint: "Yıllık bakım zamanı geldi."
        )]
        var engine = GameEngine(state: state, catalog: catalog)

        try engine.handle(.acceptOffer(id))
        let cashBeforeParts = engine.state.cash
        let expectedPartCost = PartPricingRules.purchasePrice(
            baseCost: PartPricingRules.maintenanceBasePartCost(
                for: [.oilAndFilter, .batteryTest, .tireCheck],
                catalog: catalog
            ),
            quality: .aftermarket,
            profile: .maintenanceSupply
        )
        try engine.handle(.buyPart(jobID: id, quality: .aftermarket))
        #expect(engine.state.cash == cashBeforeParts - expectedPartCost)
        #expect(engine.state.inventory[0].purchasePrice == expectedPartCost)
        #expect(engine.state.inventory[0].partName.contains("Motor Yağı"))
        #expect(engine.state.inventory[0].partName.contains("Yağ Filtresi"))
        #expect(!engine.state.inventory[0].partName.contains("Akü"))
        try engine.handle(.setPrice(jobID: id, strategy: .fair, hidePartQuality: false))
        for task in [MaintenanceTask.oilAndFilter, .batteryTest, .tireCheck] {
            try engine.handle(.completeMaintenanceTask(jobID: id, task: task, performance: 90))
        }
        #expect(engine.state.activeJobs[0].stage == .awaitingDelivery)
        #expect(engine.state.activeJobs[0].completedMaintenanceTasks.count == 3)
    }

    @Test("Bakım parçası ve işçiliği katalogdan tek merkezde hesaplanır")
    func maintenancePricingUsesCatalog() throws {
        let catalog = try DefaultContentRepository().load()
        let tasks = MaintenanceTask.allCases

        #expect(PartPricingRules.maintenanceBasePartCost(for: tasks, catalog: catalog) == Money(minorUnits: 575_000))
        #expect(PartPricingRules.maintenanceLaborValue(for: tasks, catalog: catalog) == Money(minorUnits: 500_000))
        #expect(PartPricingRules.purchasePrice(
            baseCost: Money(minorUnits: 575_000),
            quality: .original,
            profile: .maintenanceSupply
        ) == Money(minorUnits: 776_250))
        #expect(PartQuality.used.title(for: .maintenanceSupply) == "Ekonomik")
        #expect(PartQuality.used.title(for: .replacementPart) == "Çıkma")
    }

    @Test("Hasarlı araçta üçlü inceleme bilgi verir, gizli kusur riski satın alımda kalır")
    func salvageMarketRules() throws {
        let catalog = try DefaultContentRepository().load()
        var engine = GameEngine(catalog: catalog, seed: 99)
        try engine.handle(.grantPurchase(transactionID: "test-funds", cash: Money(minorUnits: 200_000_000), themeID: nil))
        try engine.handle(.prepareWorld)
        let lot = try #require(engine.state.auction?.lots.first)

        #expect(lot.fixedPrice == lot.currentBid)
        #expect(lot.severity == .heavy)
        #expect(lot.panelDamages.count == VehiclePanel.exteriorCases.count)
        #expect(lot.structuralDamages.count == StructuralArea.allCases.count)
        #expect(lot.structuralDamages.contains { $0.condition.requiresRepair })
        #expect(lot.mechanicalFaultIDs.count >= 3)
        #expect(lot.performedInspections.isEmpty)
        #expect(lot.revealedFaultIDs.isEmpty)

        let minuteBefore = engine.state.totalMinutes
        try engine.handle(.inspectSalvageLot(lotID: lot.id, kind: .body))
        let inspectedLot = try #require(engine.state.auction?.lots.first { $0.id == lot.id })
        #expect(engine.state.totalMinutes == minuteBefore + SalvageInspectionKind.body.durationMinutes)
        #expect(inspectedLot.performedInspections == [.body])
        #expect(inspectedLot.revealedPanelIDs.count == VehiclePanel.exteriorCases.count)
        #expect(throws: GameRuleError.self) {
            try engine.handle(.inspectSalvageLot(lotID: lot.id, kind: .body))
        }

        try engine.handle(.purchaseAuctionLot(lot.id))
        let project = try #require(engine.state.projectCars.first { $0.id == lot.id })
        #expect(project.faultIDs == lot.mechanicalFaultIDs)
        #expect(project.structuralDamages == lot.structuralDamages)
        #expect(engine.state.financeEntries.last?.category == .salvageVehicle)
        #expect(engine.state.incidents.last?.kind == .vehiclePurchase)
    }

    @Test("Tam hasarlı hurda araç restorasyon için satın alınamaz")
    func totalLossCannotBePurchased() throws {
        let catalog = try DefaultContentRepository().load()
        let fault = catalog.faults[0]
        let lot = AuctionLot(
            id: UUID(),
            vehicleID: catalog.vehicles[0].id,
            visibleFaultID: fault.id,
            hiddenFaultIDs: [],
            currentBid: Money(minorUnits: 1_000_000),
            competitorMaximum: Money(minorUnits: 1_000_000),
            severity: .totalLoss
        )
        var state = GameState(startingCash: Money(minorUnits: 10_000_000), daySlots: 8)
        state.auction = AuctionState(lots: [lot])
        var engine = GameEngine(state: state, catalog: catalog)

        #expect(throws: GameRuleError.self) {
            try engine.handle(.purchaseAuctionLot(lot.id))
        }
        #expect(engine.state.projectCars.isEmpty)
    }

    @Test("Dükkân açık bırakılınca kendiliğinden para harcanmaz")
    func noPassiveCashLoss() throws {
        let catalog = try DefaultContentRepository().load()
        var engine = GameEngine(catalog: catalog, seed: 10)
        let cash = engine.state.cash

        try engine.handle(.prepareWorld)

        #expect(engine.state.cash == cash)
        #expect(engine.state.financeEntries.isEmpty)
    }

    @Test("Gün giderleri kira, faturalar ve sarf olarak ayrı kaydedilir")
    func visibleOperatingCosts() throws {
        let catalog = try DefaultContentRepository().load()
        var engine = GameEngine(catalog: catalog, seed: 10)

        try engine.handle(.advanceTime(minutes: 1_440))

        let categories = Set(engine.state.financeEntries.map(\.category))
        #expect(categories.contains(.rent))
        #expect(categories.contains(.utilities))
        #expect(categories.contains(.supplies))
    }

    @Test("Yıkama alanı açıldıktan sonra araç yıkanır ve gider kaydı oluşur")
    func vehicleWashBeforeDelivery() throws {
        let catalog = try DefaultContentRepository().load()
        let fault = catalog.faults[0]
        var engine = try makeReadyForRepairEngine(catalog: catalog, fault: fault, shopLevel: 3)
        try engine.handle(.upgradeWashBay)
        let id = try #require(engine.state.activeJobs.first?.id)
        try engine.handle(.completeRepair(jobID: id, performance: 90))

        try engine.handle(.washVehicle(jobID: id))

        #expect(engine.state.activeJobs[0].isWashed)
        #expect(engine.state.financeEntries.last?.category == .wash)
    }

    @Test("Yıkama bölümü dükkân şartlarıyla üç seviyeye ilerler")
    func washBayHasThreeProgressionLevels() throws {
        let catalog = try DefaultContentRepository().load()
        var state = GameState(startingCash: Money(minorUnits: 100_000_000), daySlots: 8)
        state.shopLevel = 7
        var engine = GameEngine(state: state, catalog: catalog)

        try engine.handle(.upgradeWashBay)
        try engine.handle(.upgradeWashBay)
        try engine.handle(.upgradeWashBay)

        #expect(engine.state.washLevel == 3)
        #expect(WashBayRules.currentDefinition(for: engine.state, catalog: catalog)?.ratingBonus == 3)
        #expect(throws: GameRuleError.self) {
            try engine.handle(.upgradeWashBay)
        }
    }

    @Test("Çırak kalite seçimiyle işi paralel tamamlar, fiyat ve teslim ustada kalır")
    func apprenticeAssignment() throws {
        let catalog = try DefaultContentRepository().load()
        let fault = try #require(catalog.faults.first { $0.requiredSkill == 1 })
        var engine = makeFaultEngine(catalog: catalog, fault: fault, shopLevel: 2)
        try engine.handle(.grantPurchase(transactionID: "apprentice-funds", cash: Money(minorUnits: 5_000_000), themeID: nil))
        try engine.handle(.postApprenticeAd)
        try engine.handle(.checkApprenticeApplications)
        let application = try #require(engine.state.apprenticeRecruitment?.applications.first)
        try engine.handle(.acceptApprenticeApplication(application.id))
        let apprentice = try #require(engine.state.apprentices.first)
        let jobID = try #require(engine.state.offers.first?.id)
        try engine.handle(.acceptOffer(jobID))

        let assignedAt = engine.state.totalMinutes
        try engine.handle(.assignApprentice(
            apprenticeID: apprentice.id,
            jobID: jobID,
            partQuality: .aftermarket
        ))
        #expect(engine.state.totalMinutes == assignedAt)
        #expect(engine.state.activeJobs[0].stage == .apprenticeWorking)
        let saved = try JSONEncoder().encode(engine.state)
        let restored = try JSONDecoder().decode(GameState.self, from: saved)
        #expect(restored.activeJobs[0].apprenticeWorkOrder?.partQuality == .aftermarket)

        try engine.handle(.advanceTime(minutes: 300))
        #expect(engine.state.activeJobs[0].stage == .awaitingPrice)
        #expect(engine.state.activeJobs[0].diagnosedFaultID == fault.id)
        try engine.handle(.setPrice(jobID: jobID, strategy: .fair, hidePartQuality: false))
        #expect(engine.state.activeJobs[0].stage == .apprenticeWorking)
        try engine.handle(.advanceTime(minutes: 300))

        #expect(engine.state.activeJobs[0].stage == .awaitingDelivery)
        #expect(engine.state.apprentices[0].experience > 0)
        #expect(engine.state.apprentices[0].expertise[fault.area]?.experience ?? 0 > 0)
    }

    @Test("Çırak alan seviyesi yetmeyen tamire atanamaz")
    func apprenticeSkillGate() throws {
        let catalog = try DefaultContentRepository().load()
        let fault = try #require(catalog.faults.first { $0.requiredSkill >= 4 })
        var engine = makeFaultEngine(catalog: catalog, fault: fault, shopLevel: 2)
        var state = engine.state
        let apprentice = Apprentice(id: UUID(), name: "Mert")
        state.apprentices = [apprentice]
        engine = GameEngine(state: state, catalog: catalog)
        let jobID = try #require(engine.state.offers.first?.id)
        try engine.handle(.acceptOffer(jobID))

        #expect(throws: GameRuleError.self) {
            try engine.handle(.assignApprentice(
                apprenticeID: apprentice.id,
                jobID: jobID,
                partQuality: .aftermarket
            ))
        }
        #expect(engine.state.activeJobs[0].stage == .awaitingInspection)
    }

    @Test("Her çırak aracı yıkayıp genel tecrübe kazanabilir")
    func apprenticeCanWashVehicle() throws {
        let catalog = try DefaultContentRepository().load()
        let fault = catalog.faults[0]
        var engine = try makeReadyForRepairEngine(catalog: catalog, fault: fault, shopLevel: 3)
        try engine.handle(.upgradeWashBay)
        let jobID = try #require(engine.state.activeJobs.first?.id)
        try engine.handle(.completeRepair(jobID: jobID, performance: 90))
        var state = engine.state
        let apprentice = Apprentice(id: UUID(), name: "Efe")
        state.apprentices = [apprentice]
        engine = GameEngine(state: state, catalog: catalog)

        let events = try engine.handle(.assignApprenticeToWash(apprenticeID: apprentice.id, jobID: jobID))

        #expect(engine.state.activeJobs[0].isWashed)
        #expect(engine.state.apprentices[0].experience == 8)
        #expect(events.contains(.apprenticeWashed(name: "Efe")))
    }

    @Test("Aynı seed aynı çırak başvurusunu üretir ve ret başvuruyu kaldırır")
    func deterministicApprenticeApplications() throws {
        let catalog = try DefaultContentRepository().load()
        var firstState = GameState(startingCash: Money(minorUnits: 5_000_000), daySlots: 8, randomSeed: 123)
        firstState.shopLevel = 2
        let secondState = firstState
        var first = GameEngine(state: firstState, catalog: catalog)
        var second = GameEngine(state: secondState, catalog: catalog)

        try first.handle(.postApprenticeAd)
        try second.handle(.postApprenticeAd)
        try first.handle(.checkApprenticeApplications)
        try second.handle(.checkApprenticeApplications)

        let firstApplication = try #require(first.state.apprenticeRecruitment?.applications.first)
        let secondApplication = try #require(second.state.apprenticeRecruitment?.applications.first)
        #expect(firstApplication == secondApplication)
        #expect(firstApplication.traits.count == 2)
        #expect(firstApplication.revealedTraits.count <= 1)
        #expect(firstApplication.revealedTraits.allSatisfy(firstApplication.traits.contains))
        try first.handle(.rejectApprenticeApplication(firstApplication.id))
        #expect(first.state.apprenticeRecruitment?.applications.isEmpty == true)
    }

    @Test("Çırak özellikleri görevlerle açılır, hız ve disiplin performansı etkiler")
    func apprenticeTraitsAffectWorkAndReveal() {
        var apprentice = Apprentice(
            id: UUID(),
            name: "Can",
            traits: [.hardworking, .disciplined]
        )
        let regular = Apprentice(id: UUID(), name: "Efe")

        #expect(ApprenticeRules.adjustedDuration(baseMinutes: 100, apprentice: apprentice) == 80)
        #expect(
            ApprenticeRules.performance(apprentice: apprentice, area: .engine, randomBonus: 0)
                > ApprenticeRules.performance(apprentice: regular, area: .engine, randomBonus: 0)
        )

        #expect(apprentice.recordRepair(quality: .good).isEmpty)
        #expect(apprentice.recordWash().isEmpty)
        let firstReveal = apprentice.recordRepair(quality: .acceptable)
        #expect(firstReveal.count == 1)
        for _ in 0..<4 { _ = apprentice.recordWash() }
        #expect(apprentice.revealedTraits.count == 2)
        #expect(apprentice.happiness > 65)
    }

    @Test("Çırağa prim vermek mutluluğu artırır ve kasa hareketine yazılır")
    func apprenticeBonus() throws {
        let catalog = try DefaultContentRepository().load()
        var state = GameState(startingCash: Money(minorUnits: 5_000_000), daySlots: 8)
        let apprentice = Apprentice(id: UUID(), name: "Arda", happiness: 40)
        state.apprentices = [apprentice]
        var engine = GameEngine(state: state, catalog: catalog)
        let cashBefore = engine.state.cash

        try engine.handle(.giveApprenticeBonus(apprentice.id))

        #expect(engine.state.apprentices[0].happiness == 55)
        #expect(engine.state.cash == cashBefore - catalog.balance.apprenticeBonusCost)
        #expect(engine.state.financeEntries.last?.category == .wages)
    }

    @Test("Memnun müşteri iyi iş çıkaran çırağı sonraki gelişinde ismen sorar")
    func apprenticeCustomerFansAskForThem() throws {
        let catalog = try DefaultContentRepository().load()
        var state = GameState(startingCash: catalog.balance.startingCash, daySlots: 8, randomSeed: 51)
        state.apprentices = [Apprentice(
            id: UUID(),
            name: "Mert",
            customerFans: Set(catalog.customers.map(\.id))
        )]
        var engine = GameEngine(state: state, catalog: catalog)

        try engine.handle(.prepareWorld)

        #expect(engine.state.offers.first?.complaint.contains("Mert burada mı") == true)
    }

    @Test("Uyarıdan sonra mutsuz girişimci çırak ayrılır ve müşterilerinin bir kısmını götürür")
    func entrepreneurialApprenticeCanLeaveWithCustomers() throws {
        let catalog = try DefaultContentRepository().load()
        var state = GameState(startingCash: Money(minorUnits: 10_000_000), daySlots: 8, randomSeed: 4)
        state.totalMinutes = 6 * 1_440 + 480
        state.day = state.totalMinutes / 1_440 + 1
        let warningMinute = state.totalMinutes - 2 * 1_440
        let fanIDs = Set(catalog.customers.prefix(3).map(\.id))
        state.apprentices = [Apprentice(
            id: UUID(),
            name: "Can",
            level: 3,
            traits: [.entrepreneurial, .disciplined],
            revealedTraits: [.entrepreneurial, .disciplined],
            happiness: 55,
            hiredAtMinute: 0,
            jobsCompleted: 12,
            customerFans: fanIDs,
            departureWarningMinute: warningMinute,
            lastRetentionCheckDay: state.day
        )]
        var engine = GameEngine(state: state, catalog: catalog)

        let events = try engine.handle(.advanceTime(minutes: 1_440))

        #expect(engine.state.apprentices.isEmpty)
        #expect(!engine.state.lostCustomerIDs.isEmpty)
        #expect(events.contains { if case .apprenticeLeft(name: "Can", customersTaken: 2) = $0 { true } else { false } })
    }

    @Test("Ayrılık uyarısı alan çırak yüksek mutlulukla dükkânda kalır")
    func happyApprenticeStaysAfterWarning() throws {
        let catalog = try DefaultContentRepository().load()
        var state = GameState(startingCash: Money(minorUnits: 10_000_000), daySlots: 8)
        state.totalMinutes = 5 * 1_440 + 480
        state.day = state.totalMinutes / 1_440 + 1
        let apprentice = Apprentice(
            id: UUID(),
            name: "Efe",
            level: 2,
            traits: [.entrepreneurial, .hardworking],
            revealedTraits: [.entrepreneurial, .hardworking],
            happiness: 85,
            hiredAtMinute: 0,
            jobsCompleted: 8,
            departureWarningMinute: state.totalMinutes - 2 * 1_440,
            lastRetentionCheckDay: state.day
        )
        state.apprentices = [apprentice]
        var engine = GameEngine(state: state, catalog: catalog)

        let events = try engine.handle(.advanceTime(minutes: 1_440))

        #expect(engine.state.apprentices.count == 1)
        #expect(engine.state.apprentices[0].departureWarningMinute == nil)
        #expect(events.contains(.apprenticeStayed(name: "Efe")))
    }

    @Test("Kredi limit içinde alınır ve oyun zamanı ilerlediğinde taksiti tahsil edilir")
    func bankLoanSchedule() throws {
        let catalog = try DefaultContentRepository().load()
        var engine = GameEngine(catalog: catalog, seed: 77)
        let amount = Money(minorUnits: 5_000_000)
        let cashBefore = engine.state.cash

        try engine.handle(.takeLoan(amount: amount, plan: .short))
        let loan = try #require(engine.state.loans.first)
        #expect(engine.state.cash == cashBefore + amount)
        #expect(loan.totalRepayment > amount)
        #expect(BankingRules.availableCredit(for: engine.state) < BankingRules.creditLimit(for: engine.state))

        let balanceBefore = loan.remainingBalance
        try engine.handle(.advanceTime(minutes: LoanPlan.short.installmentIntervalDays * 1_440))

        #expect(engine.state.loans.first?.remainingBalance ?? .zero < balanceBefore)
        #expect(engine.state.financeEntries.contains { $0.category == .loanPayment })
        #expect(engine.state.incidents.contains { $0.kind == .loan && $0.cashImpact.minorUnits < 0 })
    }

    @Test("Denetim ve şikâyet sonuçları etkileriyle olay defterinde kalır")
    func consequenceIncidentLedger() throws {
        let catalog = try DefaultContentRepository().load()
        var state = GameState(startingCash: catalog.balance.startingCash, daySlots: 8)
        state.consequences = [ScheduledConsequence(
            id: UUID(),
            dueDay: 2,
            kind: .inspection,
            amount: Money(minorUnits: 125_000),
            message: "Denetim kaydı testi"
        )]
        var engine = GameEngine(state: state, catalog: catalog)

        try engine.handle(.advanceTime(minutes: 1_440))

        let incident = try #require(engine.state.incidents.last)
        #expect(incident.kind == .inspection)
        #expect(incident.message == "Denetim kaydı testi")
        #expect(incident.cashImpact == Money(minorUnits: -125_000))
        #expect(incident.ratingImpact == -3)
        #expect(incident.suspicionImpact == -8)
    }

    @Test("Yüksek ilan fiyatı satış ihtimalini düşürür")
    func listingPriceChangesSaleChance() throws {
        let catalog = try DefaultContentRepository().load()
        let vehicle = catalog.vehicles[0]
        var project = ProjectCar(
            id: UUID(),
            vehicleID: vehicle.id,
            faultIDs: [catalog.faults[0].id],
            purchasePrice: Money(minorUnits: 6_000_000)
        )
        project.stage = .readyForSale
        project.restorationQuality = 86
        let fair = VehicleTradingRules.fairPrice(project: project, vehicle: vehicle)
        let fairEstimate = VehicleTradingRules.listingEstimate(
            project: project,
            vehicle: vehicle,
            askingPrice: fair,
            ratingTenths: 40,
            hasShowroom: false,
            discloseDamage: true
        )
        let expensiveEstimate = VehicleTradingRules.listingEstimate(
            project: project,
            vehicle: vehicle,
            askingPrice: Money(minorUnits: fair.minorUnits * 140 / 100),
            ratingTenths: 40,
            hasShowroom: false,
            discloseDamage: true
        )

        #expect(fairEstimate.saleChancePercent > expensiveEstimate.saleChancePercent)
    }

    @Test("Alıcı kontrolü aracı satmaz; teklif oyuncunun onayını bekler")
    func projectCarListingFlow() throws {
        let catalog = try DefaultContentRepository().load()
        let vehicle = catalog.vehicles[0]
        var state = GameState(startingCash: Money(minorUnits: 100_000_000), daySlots: 8, randomSeed: 4)
        state.shopLevel = 7
        var project = ProjectCar(
            id: UUID(),
            vehicleID: vehicle.id,
            faultIDs: [catalog.faults[0].id],
            purchasePrice: Money(minorUnits: 5_000_000)
        )
        project.stage = .readyForSale
        project.restorationQuality = 92
        state.projectCars = [project]
        var engine = GameEngine(state: state, catalog: catalog)
        let fair = VehicleTradingRules.fairPrice(project: project, vehicle: vehicle)
        let fastPrice = Money(minorUnits: fair.minorUnits * 80 / 100)

        try engine.handle(.listProjectCar(projectID: project.id, askingPrice: fastPrice, discloseDamage: true))
        #expect(engine.state.projectCars.first?.stage == .listed)
        #expect(engine.state.financeEntries.last?.category == .listingFee)

        for _ in 0..<10 {
            if engine.state.projectCars.first?.buyerOffers.isEmpty == false { break }
            try engine.handle(.checkVehicleListings)
        }
        let offer = try #require(engine.state.projectCars.first?.buyerOffers.first)
        #expect(engine.state.projectCars.count == 1)
        #expect(!engine.state.financeEntries.contains { $0.category == .vehicleSale })

        try engine.handle(.acceptVehicleOffer(projectID: project.id, offerID: offer.id))
        #expect(engine.state.projectCars.isEmpty)
        #expect(engine.state.financeEntries.contains { $0.category == .vehicleSale })
    }

    @Test("Pazarlık alıcının gizli limitine yakınsa karşı teklif üretir, çok yüksekse alıcı çekilir")
    func vehicleOfferNegotiationUsesBuyerLimit() throws {
        let catalog = try DefaultContentRepository().load()
        let vehicle = catalog.vehicles[0]
        var state = GameState(startingCash: Money(minorUnits: 100_000_000), daySlots: 8)
        var project = ProjectCar(
            id: UUID(),
            vehicleID: vehicle.id,
            faultIDs: [],
            purchasePrice: Money(minorUnits: 5_000_000)
        )
        project.stage = .listed
        project.askingPrice = Money(minorUnits: 10_000_000)
        let nearOffer = VehicleBuyerOffer(
            id: UUID(),
            buyerName: "Pazarlıkçı alıcı",
            amount: Money(minorUnits: 8_000_000),
            maximumAmount: Money(minorUnits: 9_000_000),
            createdAtMinute: state.totalMinutes
        )
        let lowBudgetOffer = VehicleBuyerOffer(
            id: UUID(),
            buyerName: "Temkinli alıcı",
            amount: Money(minorUnits: 7_000_000),
            maximumAmount: Money(minorUnits: 8_000_000),
            createdAtMinute: state.totalMinutes
        )
        project.buyerOffers = [nearOffer, lowBudgetOffer]
        state.projectCars = [project]
        var engine = GameEngine(state: state, catalog: catalog)

        try engine.handle(.negotiateVehicleOffer(
            projectID: project.id,
            offerID: nearOffer.id,
            counterOffer: Money(minorUnits: 9_200_000)
        ))
        #expect(engine.state.projectCars[0].buyerOffers.first { $0.id == nearOffer.id }?.amount == Money(minorUnits: 9_000_000))

        try engine.handle(.negotiateVehicleOffer(
            projectID: project.id,
            offerID: lowBudgetOffer.id,
            counterOffer: Money(minorUnits: 9_000_000)
        ))
        #expect(!engine.state.projectCars[0].buyerOffers.contains { $0.id == lowBudgetOffer.id })
    }

    @Test("Hasarlı araç mekanik, kaporta ve güvenlik işleri tek tek bitmeden satışa hazır olmaz")
    func projectCarRequiresEveryRepairTask() throws {
        let catalog = try DefaultContentRepository().load()
        let vehicle = catalog.vehicles[0]
        let fault = catalog.faults[0]
        var state = GameState(startingCash: Money(minorUnits: 100_000_000), daySlots: 8)
        state.shopLevel = 7
        let project = ProjectCar(
            id: UUID(),
            vehicleID: vehicle.id,
            faultIDs: [fault.id],
            purchasePrice: Money(minorUnits: 5_000_000),
            panelDamages: [PanelDamage(panel: .leftFrontDoor, condition: .replaced)],
            structuralDamages: [StructuralDamage(area: .leftPodye, condition: .bent)],
            airbagsDeployed: true,
            startsAndDrives: false
        )
        state.projectCars = [project]
        var engine = GameEngine(state: state, catalog: catalog)

        try engine.handle(.completeProjectRepair(
            projectID: project.id,
            task: .mechanical(faultID: fault.id),
            performance: 80
        ))
        #expect(engine.state.projectCars[0].stage == .awaitingRepair)

        try engine.handle(.completeProjectRepair(
            projectID: project.id,
            task: .structural(.leftPodye),
            performance: 86
        ))
        #expect(engine.state.projectCars[0].stage == .awaitingRepair)

        try engine.handle(.completeProjectRepair(
            projectID: project.id,
            task: .panel(.leftFrontDoor),
            performance: 84
        ))
        #expect(engine.state.projectCars[0].stage == .awaitingRepair)

        try engine.handle(.completeProjectRepair(
            projectID: project.id,
            task: .airbag,
            performance: 88
        ))
        #expect(engine.state.projectCars[0].stage == .readyForSale)
        #expect(engine.state.projectCars[0].completedRepairTasks.count == 4)
        #expect(engine.state.financeEntries.filter { $0.category == .restoration }.count == 4)
    }

    @Test("Ekspertiz hesabı alış, onarım, satış ve kâr aralıklarını tutarlı üretir")
    func investmentEstimateIsConsistent() throws {
        let catalog = try DefaultContentRepository().load()
        var engine = GameEngine(catalog: catalog, seed: 91)
        try engine.handle(.prepareWorld)
        let lot = try #require(engine.state.auction?.lots.first)
        let vehicle = try #require(catalog.vehicle(id: lot.vehicleID))
        let estimate = VehicleTradingRules.investmentEstimate(
            lot: lot,
            vehicle: vehicle,
            catalog: catalog,
            hasBodyPaintBooth: false
        )

        #expect(estimate.repairLow <= estimate.repairHigh)
        #expect(estimate.totalInvestmentLow == lot.fixedPrice + estimate.repairLow)
        #expect(estimate.profitLow == estimate.fairSaleLow - estimate.totalInvestmentHigh)
        #expect(estimate.profitHigh == estimate.fairSaleHigh - estimate.totalInvestmentLow)
    }

    @Test("Kriz oyunu bitirmez ve veresiye desteğiyle devam eder")
    func recoverableCrisis() throws {
        let catalog = try DefaultContentRepository().load()
        var engine = GameEngine(catalog: catalog)
        try engine.handle(.advanceTime(minutes: 25 * 1_440))

        #expect(engine.state.day == 26)
        #expect(engine.state.cash >= Money(minorUnits: -500_000))
        try engine.handle(.prepareWorld)
        #expect(!engine.state.offers.isEmpty)
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

    @Test("Eski kayıt yeni zaman, uzmanlık ve yorum alanlarına taşınır")
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
        for key in ["inventory", "totalMinutes", "nextCustomerArrivalMinute", "expertise", "reviews", "ratingTenths", "apprentices", "apprenticeRecruitment", "lostCustomerIDs", "financeEntries", "loans", "incidents", "washLevel"] {
            object.removeValue(forKey: key)
        }
        let legacyData = try JSONSerialization.data(withJSONObject: object)
        try legacyData.write(to: directory.appendingPathComponent("ototamir-save.json"))

        let repository = JSONFileSaveRepository(directory: directory)
        let migrated = try #require(try await repository.load())
        #expect(migrated.schemaVersion == GameState.currentSchemaVersion)
        #expect(migrated.inventory.isEmpty)
        #expect(migrated.totalMinutes > 0)
        #expect(migrated.expertise.count == SkillArea.allCases.count)
        #expect(migrated.incidents.isEmpty)
    }

    @Test("Eski güven değeri dükkân puanına taşınır")
    func legacyTrustMigratesToShopRating() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ototamir-trust-migration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let catalog = try DefaultContentRepository().load()
        var legacy = GameState(startingCash: catalog.balance.startingCash, daySlots: 8)
        legacy.schemaVersion = 14
        legacy.ratingTenths = 38
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let encoded = try encoder.encode(legacy)
        var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object["reputation"] = ["craftsmanship": 42, "trust": 35, "suspicion": 7]
        let legacyData = try JSONSerialization.data(withJSONObject: object)
        try legacyData.write(to: directory.appendingPathComponent("ototamir-save.json"))

        let repository = JSONFileSaveRepository(directory: directory)
        let migrated = try #require(try await repository.load())

        #expect(migrated.schemaVersion == GameState.currentSchemaVersion)
        #expect(migrated.ratingTenths == 43)
        #expect(migrated.reputation.craftsmanship == 42)
        #expect(migrated.reputation.suspicion == 7)
        let migratedData = try encoder.encode(migrated)
        let migratedObject = try #require(JSONSerialization.jsonObject(with: migratedData) as? [String: Any])
        let reputation = try #require(migratedObject["reputation"] as? [String: Any])
        #expect(reputation["trust"] == nil)
    }

    @Test("Kontrolü yapılmış iş kayıt turunda teşhis aşamasını korur")
    func diagnosisStageSurvivesSaveRoundTrip() throws {
        let catalog = try DefaultContentRepository().load()
        let fault = catalog.faults[0]
        var engine = makeFaultEngine(catalog: catalog, fault: fault)
        let id = try #require(engine.state.offers.first?.id)
        try engine.handle(.acceptOffer(id))
        for kind in Array(fault.inspectionFindings.keys.prefix(2)) {
            try engine.handle(.performInspection(jobID: id, kind: kind))
        }

        let data = try JSONEncoder().encode(engine.state)
        let restored = try JSONDecoder().decode(GameState.self, from: data)
        #expect(restored.activeJobs[0].stage == .awaitingDiagnosis)
        #expect(restored.activeJobs[0].complaint == fault.complaint)
    }

    private func makeFaultEngine(
        catalog: ContentCatalog,
        fault: FaultDefinition,
        alternative: FaultDefinition? = nil,
        shopLevel: Int = 1
    ) -> GameEngine {
        var state = GameState(startingCash: catalog.balance.startingCash, daySlots: 8, randomSeed: 7)
        state.shopLevel = shopLevel
        let alternatives = alternative.map { [$0.id] } ?? []
        state.offers = [CustomerOffer(
            id: UUID(),
            customerID: catalog.customers[0].id,
            vehicleID: catalog.vehicles[0].id,
            actualFaultID: fault.id,
            suspectedFaultIDs: [fault.id] + alternatives,
            complaint: fault.complaint
        )]
        return GameEngine(state: state, catalog: catalog)
    }

    private func makeReadyForRepairEngine(
        catalog: ContentCatalog,
        fault: FaultDefinition,
        shopLevel: Int
    ) throws -> GameEngine {
        var engine = makeFaultEngine(catalog: catalog, fault: fault, shopLevel: shopLevel)
        let id = try #require(engine.state.offers.first?.id)
        try engine.handle(.acceptOffer(id))
        for kind in Array(fault.inspectionFindings.keys.prefix(2)) {
            try engine.handle(.performInspection(jobID: id, kind: kind))
        }
        try engine.handle(.diagnose(jobID: id, faultID: fault.id))
        try engine.handle(.buyPart(jobID: id, quality: .aftermarket))
        try engine.handle(.setPrice(jobID: id, strategy: .fair, hidePartQuality: false))
        return engine
    }
}
