#if DEBUG
import Foundation
import GameDomain
import GameLogic

enum QAScenarioFactory {
    static func make(named name: String, catalog: ContentCatalog) throws -> GameState? {
        switch name {
        case "workshop-control":
            return try workshopState(catalog: catalog, stage: .awaitingInspection)
        case "workshop-part":
            return try workshopState(catalog: catalog, stage: .awaitingPart)
        case "workshop-diagnosis":
            return try workshopState(catalog: catalog, stage: .awaitingDiagnosis)
        case "workshop-repair":
            return try workshopState(catalog: catalog, stage: .readyForRepair)
        case "workshop-price":
            return try workshopState(catalog: catalog, stage: .awaitingPrice)
        case "auction-market":
            return try auctionMarketState(catalog: catalog)
        case "auction-project":
            return try projectState(catalog: catalog, stage: .awaitingRepair)
        case "listing-ready":
            return try projectState(catalog: catalog, stage: .readyForSale)
        case "auction-listed":
            return try projectState(catalog: catalog, stage: .listed)
        case "listing-listed":
            return try projectState(catalog: catalog, stage: .listed)
        case "progress":
            return try progressState(catalog: catalog)
        case "workshop-maintenance":
            return try maintenanceState(catalog: catalog)
        case "workshop-mixed":
            return try mixedWorkshopState(catalog: catalog)
        default:
            if name.hasPrefix("workshop-minigame-"),
               let kind = RepairGameKind(rawValue: String(name.dropFirst("workshop-minigame-".count))) {
                return try miniGameState(catalog: catalog, kind: kind)
            }
            return nil
        }
    }

    private static func miniGameState(catalog: ContentCatalog, kind: RepairGameKind) throws -> GameState {
        let fault = try required(catalog.faults.first { $0.repairGame == kind }, "QA mini oyun arızası")
        var state = baseState(catalog: catalog)
        let offer = CustomerOffer(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000301")!,
            customerID: catalog.customers[0].id,
            vehicleID: catalog.vehicles[0].id,
            actualFaultID: fault.id,
            suspectedFaultIDs: [fault.id],
            complaint: fault.complaint
        )
        var job = RepairJob(offer: offer)
        job.stage = .readyForRepair
        job.diagnosedFaultID = fault.id
        job.partQuality = .aftermarket
        state.activeJobs = [job]
        state.inventory = [InventoryItem(
            id: offer.id,
            jobID: offer.id,
            faultID: fault.id,
            partName: fault.partName,
            quality: .aftermarket,
            purchasePrice: fault.basePartCost
        )]
        return state
    }

    private static func baseState(catalog: ContentCatalog, seed: UInt64 = 7) -> GameState {
        var state = GameState(startingCash: Money(minorUnits: 180_000_000), daySlots: 8, randomSeed: seed)
        state.shopLevel = 7
        state.ratingTenths = 46
        state.reputation = Reputation(craftsmanship: 72, trust: 68, suspicion: 12)
        return state
    }

    private static func workshopState(catalog: ContentCatalog, stage: RepairStage) throws -> GameState {
        let fault = try required(catalog.faults.first, "QA arızası")
        var state = baseState(catalog: catalog)
        let offer = CustomerOffer(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
            customerID: catalog.customers[1].id,
            vehicleID: catalog.vehicles[2].id,
            actualFaultID: fault.id,
            suspectedFaultIDs: Array(catalog.faults.prefix(4).map(\.id)),
            complaint: fault.complaint
        )
        state.offers = [offer]
        var engine = GameEngine(state: state, catalog: catalog)
        try engine.handle(.acceptOffer(offer.id))
        if stage != .awaitingInspection {
            for kind in Array(fault.inspectionFindings.keys.sorted { $0.rawValue < $1.rawValue }.prefix(2)) {
                try engine.handle(.performInspection(jobID: offer.id, kind: kind))
            }
        }
        if stage != .awaitingInspection && stage != .awaitingDiagnosis {
            try engine.handle(.diagnose(jobID: offer.id, faultID: fault.id))
        }
        if stage == .readyForRepair || stage == .awaitingPrice {
            try engine.handle(.buyPart(jobID: offer.id, quality: .aftermarket))
        }
        if stage == .awaitingPrice {
            try engine.handle(.completeRepair(jobID: offer.id, performance: 88))
        }
        var result = engine.state
        if stage == .readyForRepair {
            result.apprentices = [Apprentice(id: UUID(), name: "Çırak Memo", level: 3, experience: 84)]
        }
        return result
    }

    private static func maintenanceState(catalog: ContentCatalog) throws -> GameState {
        var state = baseState(catalog: catalog)
        let offer = CustomerOffer(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000401")!,
            customerID: catalog.customers[2].id,
            vehicleID: catalog.vehicles[3].id,
            serviceKind: .periodicMaintenance,
            actualFaultID: nil,
            suspectedFaultIDs: [],
            maintenanceTasks: MaintenanceTask.allCases,
            complaint: "Yıllık bakım zamanı geldi; bütün kontrolleri yapalım."
        )
        state.offers = [offer]
        state.apprentices = [Apprentice(id: UUID(), name: "Çırak Memo", level: 3, experience: 84)]
        var engine = GameEngine(state: state, catalog: catalog)
        try engine.handle(.acceptOffer(offer.id))
        try engine.handle(.buyPart(jobID: offer.id, quality: .aftermarket))
        return engine.state
    }

    private static func mixedWorkshopState(catalog: ContentCatalog) throws -> GameState {
        var state = try workshopState(catalog: catalog, stage: .awaitingDiagnosis)
        var engine = GameEngine(state: state, catalog: catalog)
        try engine.handle(.prepareWorld)
        let lot = try required(engine.state.auction?.lots.first, "QA proje aracı")
        try engine.handle(.purchaseAuctionLot(lot.id))
        state = engine.state
        return state
    }

    private static func auctionMarketState(catalog: ContentCatalog) throws -> GameState {
        var engine = GameEngine(state: baseState(catalog: catalog, seed: 91), catalog: catalog)
        try engine.handle(.prepareWorld)
        var state = engine.state
        if let first = state.auction?.lots.first { state.auction = AuctionState(lots: [first]) }
        return state
    }

    private static func projectState(catalog: ContentCatalog, stage: ProjectCarStage) throws -> GameState {
        var engine = GameEngine(state: baseState(catalog: catalog, seed: 99), catalog: catalog)
        try engine.handle(.prepareWorld)
        let lot = try required(engine.state.auction?.lots.first, "QA hasarlı aracı")
        try engine.handle(.purchaseAuctionLot(lot.id))
        if stage != .awaitingRepair {
            let project = try required(engine.state.projectCars.first, "QA proje aracı")
            let tasks: [ProjectRepairTask] = project.faultIDs.map { .mechanical(faultID: $0) }
                + project.panelDamages.filter {
                    VehiclePanel.exteriorCases.contains($0.panel) && $0.condition != .original
                }.map { .panel($0.panel) }
                + project.structuralDamages.filter { $0.condition.requiresRepair }.map { .structural($0.area) }
                + (project.airbagsDeployed ? [.airbag] : [])
            for task in tasks {
                try engine.handle(.completeProjectRepair(projectID: lot.id, task: task, performance: 88))
            }
        }
        if stage == .listed {
            let project = try required(engine.state.projectCars.first, "QA proje aracı")
            let vehicle = try required(catalog.vehicle(id: project.vehicleID), "QA araç içeriği")
            let fairPrice = VehicleTradingRules.fairPrice(project: project, vehicle: vehicle)
            try engine.handle(.listProjectCar(projectID: project.id, askingPrice: fairPrice, discloseDamage: true))
            for _ in 0..<10 where engine.state.projectCars.first?.buyerOffers.isEmpty == true {
                try engine.handle(.checkVehicleListings)
            }
        }
        var state = engine.state
        state.auction = AuctionState(lots: [])
        return state
    }

    private static func progressState(catalog: ContentCatalog) throws -> GameState {
        var state = baseState(catalog: catalog, seed: 42)
        state.apprentices = [
            Apprentice(id: UUID(uuidString: "00000000-0000-0000-0000-000000000201")!, name: "Çırak Memo", level: 3, experience: 84),
            Apprentice(id: UUID(uuidString: "00000000-0000-0000-0000-000000000202")!, name: "Çırak İsmail", level: 2, experience: 45)
        ]
        state.reviews = [
            ShopReview(id: UUID(), customerID: catalog.customers[0].id, stars: 5, text: "İşi temiz yaptı, fiyatı da baştan söyledi.", day: 4),
            ShopReview(id: UUID(), customerID: catalog.customers[3].id, stars: 4, text: "Araç düzeldi, bekleme alanı da rahattı.", day: 6)
        ]
        state.financeEntries = [
            FinanceEntry(id: UUID(), day: 6, category: .customerIncome, amount: Money(minorUnits: 1_450_000), note: "Yıllık bakım"),
            FinanceEntry(id: UUID(), day: 6, category: .parts, amount: Money(minorUnits: -420_000), note: "Bakım seti"),
            FinanceEntry(id: UUID(), day: 6, category: .utilities, amount: Money(minorUnits: -30_000), note: "Elektrik ve lift enerjisi")
        ]
        var engine = GameEngine(state: state, catalog: catalog)
        try engine.handle(.takeLoan(amount: Money(minorUnits: 15_000_000), plan: .standard))
        return engine.state
    }

    private static func required<T>(_ value: T?, _ name: String) throws -> T {
        guard let value else { throw GameRuleError.contentMissing(name) }
        return value
    }
}
#endif
