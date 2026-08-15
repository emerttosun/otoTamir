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

    @Test("Müşteri işi kontrol, parça, tamir ve fiyat sırasıyla tamamlanır")
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
        try engine.handle(.completeRepair(jobID: offer.id, performance: 100))
        #expect(engine.state.activeJobs[0].stage == .awaitingPrice)
        let events = try engine.handle(.setPrice(jobID: offer.id, strategy: .fair, hidePartQuality: false))

        #expect(engine.state.activeJobs.isEmpty)
        #expect(engine.state.inventory.isEmpty)
        #expect(engine.state.cash > startCash)
        #expect(events.contains { if case .priceSettled = $0 { true } else { false } })
        #expect(engine.state.expertise[fault.area, default: SkillProgress()].experience > 0)
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
        try engine.handle(.buyPart(jobID: id, quality: .aftermarket))
        for task in [MaintenanceTask.oilAndFilter, .batteryTest, .tireCheck] {
            try engine.handle(.completeMaintenanceTask(jobID: id, task: task, performance: 90))
        }
        #expect(engine.state.activeJobs[0].stage == .awaitingPrice)
        #expect(engine.state.activeJobs[0].completedMaintenanceTasks.count == 3)
    }

    @Test("Hasarlı araç pazarı sabit fiyat ve tam ekspertiz raporuyla satın alınır")
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
        try engine.handle(.purchaseAuctionLot(lot.id))
        #expect(engine.state.projectCars.contains { $0.id == lot.id })
        #expect(engine.state.financeEntries.last?.category == .salvageVehicle)
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
        #expect(WashBayRules.currentDefinition(for: engine.state, catalog: catalog)?.trustBonus == 3)
        #expect(throws: GameRuleError.self) {
            try engine.handle(.upgradeWashBay)
        }
    }

    @Test("Çırak işe alınır, tamire atanır ve tecrübe kazanır")
    func apprenticeAssignment() throws {
        let catalog = try DefaultContentRepository().load()
        let fault = catalog.faults[0]
        var engine = try makeReadyForRepairEngine(catalog: catalog, fault: fault, shopLevel: 2)
        try engine.handle(.grantPurchase(transactionID: "apprentice-funds", cash: Money(minorUnits: 5_000_000), themeID: nil))
        try engine.handle(.hireApprentice)
        let apprentice = try #require(engine.state.apprentices.first)
        let jobID = try #require(engine.state.activeJobs.first?.id)

        try engine.handle(.assignApprentice(apprenticeID: apprentice.id, jobID: jobID, task: nil))

        #expect(engine.state.activeJobs[0].stage == .awaitingPrice)
        #expect(engine.state.apprentices[0].experience > 0)
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
        #expect(incident.trustImpact == -3)
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

    @Test("İhale aracı mekanik, kaporta ve güvenlik işleri tek tek bitmeden satışa hazır olmaz")
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
            faults: lot.mechanicalFaultIDs.compactMap { catalog.fault(id: $0) },
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
        for key in ["inventory", "totalMinutes", "nextCustomerArrivalMinute", "expertise", "reviews", "ratingTenths", "apprentices", "financeEntries", "loans", "incidents", "washLevel"] {
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
        return engine
    }
}
