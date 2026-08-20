import Foundation
import GameDomain

public struct GameEngine: Sendable {
    public internal(set) var state: GameState
    public let catalog: ContentCatalog

    public init(state: GameState, catalog: ContentCatalog) {
        self.state = state
        self.catalog = catalog
    }

    public init(catalog: ContentCatalog, seed: UInt64 = 0x0A70_7A11) {
        self.init(
            state: GameState(
                startingCash: catalog.balance.startingCash,
                daySlots: catalog.balance.daySlots,
                randomSeed: seed
            ),
            catalog: catalog
        )
    }

    @discardableResult
    public mutating func handle(_ command: GameCommand) throws -> [GameEvent] {
        let events: [GameEvent]
        switch command {
        case .prepareWorld:
            events = prepareWorld()
        case .advanceTime(let minutes):
            guard minutes > 0 else { throw GameRuleError.invalidCommand("Zaman sıfırdan büyük ilerlemeli.") }
            events = advanceClock(by: minutes)
        case .acceptOffer(let id):
            events = try acceptOffer(id)
        case .declineOffer(let id):
            events = try declineOffer(id)
        case .performInspection(let jobID, let kind):
            events = try performInspection(jobID: jobID, kind: kind)
        case .diagnose(let jobID, let faultID):
            events = try diagnose(jobID: jobID, faultID: faultID)
        case .buyPart(let jobID, let quality):
            events = try buyPart(jobID: jobID, quality: quality)
        case .completeRepair(let jobID, let performance):
            events = try completeRepair(jobID: jobID, performance: performance)
        case .completeMaintenanceTask(let jobID, let task, let performance):
            events = try completeMaintenanceTask(jobID: jobID, task: task, performance: performance)
        case .setPrice(let jobID, let strategy, let hidePartQuality):
            events = try setPrice(jobID: jobID, strategy: strategy, hidePartQuality: hidePartQuality)
        case .respondToCustomerOffer(let jobID, let response):
            events = try respondToCustomerOffer(jobID: jobID, response: response)
        case .deliverVehicle(let jobID):
            events = try deliverVehicle(jobID: jobID)
        case .washVehicle(let jobID):
            events = try washVehicle(jobID: jobID)
        case .postApprenticeAd:
            events = try postApprenticeAd()
        case .checkApprenticeApplications:
            events = advanceClock(by: 180)
        case .acceptApprenticeApplication(let id):
            events = try acceptApprenticeApplication(id)
        case .rejectApprenticeApplication(let id):
            events = try rejectApprenticeApplication(id)
        case .assignApprentice(let apprenticeID, let jobID, let partQuality):
            events = try assignApprentice(
                apprenticeID: apprenticeID,
                jobID: jobID,
                partQuality: partQuality
            )
        case .assignApprenticeToWash(let apprenticeID, let jobID):
            events = try assignApprenticeToWash(apprenticeID: apprenticeID, jobID: jobID)
        case .giveApprenticeBonus(let apprenticeID):
            events = try giveApprenticeBonus(apprenticeID)
        case .upgradeShop:
            events = try upgradeShop()
        case .upgradeWashBay:
            events = try upgradeWashBay()
        case .inspectSalvageLot(let lotID, let kind):
            events = try inspectSalvageLot(lotID: lotID, kind: kind)
        case .purchaseAuctionLot(let lotID):
            events = try purchaseAuctionLot(lotID)
        case .completeProjectRepair(let projectID, let task, let performance):
            events = try completeProjectRepair(projectID: projectID, task: task, performance: performance)
        case .listProjectCar(let projectID, let askingPrice, let discloseDamage):
            events = try listProjectCar(projectID: projectID, askingPrice: askingPrice, discloseDamage: discloseDamage)
        case .cancelProjectListing(let projectID):
            events = try cancelProjectListing(projectID: projectID)
        case .checkVehicleListings:
            events = advanceClock(by: 180)
        case .acceptVehicleOffer(let projectID, let offerID):
            events = try acceptVehicleOffer(projectID: projectID, offerID: offerID)
        case .rejectVehicleOffer(let projectID, let offerID):
            events = try rejectVehicleOffer(projectID: projectID, offerID: offerID)
        case .negotiateVehicleOffer(let projectID, let offerID, let counterOffer):
            events = try negotiateVehicleOffer(
                projectID: projectID,
                offerID: offerID,
                counterOffer: counterOffer
            )
        case .takeLoan(let amount, let plan):
            events = try takeLoan(amount: amount, plan: plan)
        case .grantPurchase(let transactionID, let cash, let themeID):
            events = grantPurchase(transactionID: transactionID, cash: cash, themeID: themeID)
        }

        state.parentRevision = state.revision
        state.revision += 1
        state.modifiedAt = Date()
        return events
    }

}
