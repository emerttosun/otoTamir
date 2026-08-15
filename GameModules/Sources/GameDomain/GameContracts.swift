import Foundation

public enum GameCommand: Sendable {
    case prepareWorld
    case advanceTime(minutes: Int)
    case acceptOffer(UUID)
    case declineOffer(UUID)
    case performInspection(jobID: UUID, kind: InspectionKind)
    case diagnose(jobID: UUID, faultID: String)
    case buyPart(jobID: UUID, quality: PartQuality)
    case completeRepair(jobID: UUID, performance: Int)
    case completeMaintenanceTask(jobID: UUID, task: MaintenanceTask, performance: Int)
    case setPrice(jobID: UUID, strategy: PriceStrategy, hidePartQuality: Bool)
    case washVehicle(jobID: UUID)
    case hireApprentice
    case assignApprentice(apprenticeID: UUID, jobID: UUID, task: MaintenanceTask?)
    case upgradeShop
    case purchaseAuctionLot(UUID)
    case completeProjectRepair(projectID: UUID, task: ProjectRepairTask, performance: Int)
    case listProjectCar(projectID: UUID, askingPrice: Money, discloseDamage: Bool)
    case cancelProjectListing(projectID: UUID)
    case checkVehicleListings
    case takeLoan(amount: Money, plan: LoanPlan)
    case grantPurchase(transactionID: String, cash: Money?, themeID: String?)
}

public enum GameEvent: Equatable, Sendable {
    case timeAdvanced(Int)
    case customerArrived(UUID)
    case customerLeft(UUID)
    case offerAccepted(UUID)
    case inspectionCompleted(kind: InspectionKind, finding: String)
    case diagnosisCompleted(correct: Bool)
    case moneyChanged(Money, reason: String)
    case repairCompleted(WorkmanshipQuality)
    case maintenanceTaskCompleted(MaintenanceTask)
    case priceSettled(Money, reaction: String)
    case vehicleWashed(UUID)
    case apprenticeHired(Apprentice)
    case apprenticeCompleted(name: String, quality: WorkmanshipQuality)
    case experienceGained(area: SkillArea, amount: Int, level: Int)
    case reviewReceived(ShopReview)
    case reputationChanged(Reputation)
    case consequence(String)
    case tutorial(String)
    case shopUpgraded(Int)
    case auctionOpened
    case auctionWon(vehicleName: String, price: Money)
    case projectCarReady(UUID)
    case projectRepairCompleted(projectID: UUID, task: ProjectRepairTask)
    case projectCarListed(price: Money, saleChance: Int)
    case projectListingExpired(UUID)
    case projectCarSold(price: Money, honest: Bool)
    case loanTaken(amount: Money, totalRepayment: Money)
    case loanInstallmentPaid(amount: Money, remainingBalance: Money)
    case loanClosed(UUID)
    case purchaseGranted(String)
}

public enum GameRuleError: LocalizedError, Equatable, Sendable {
    case invalidCommand(String)
    case notEnoughTime
    case notEnoughMoney
    case shopIsFull
    case contentMissing(String)

    public var errorDescription: String? {
        switch self {
        case .invalidCommand(let reason): reason
        case .notEnoughTime: "Bu işlem için oyun zamanı ilerletilemedi."
        case .notEnoughMoney: "Kasada bu işlem için yeterli para yok."
        case .shopIsFull: "Dükkânda boş araç yeri yok."
        case .contentMissing(let id): "İçerik bulunamadı: \(id)"
        }
    }
}

public protocol RandomSource: Sendable {
    mutating func next(upperBound: Int) -> Int
}

public protocol ContentRepository: Sendable {
    func load() throws -> ContentCatalog
}

public protocol SaveRepository: Sendable {
    func load() async throws -> GameState?
    func save(_ state: GameState) async throws
}

public enum CloudSyncResult: Sendable {
    case unavailable
    case uploaded
    case downloaded(GameState)
    case conflict(local: GameState, remote: GameState)
}

public protocol CloudSyncService: Sendable {
    func synchronize(local: GameState) async -> CloudSyncResult
}

public struct CommerceProduct: Identifiable, Hashable, Sendable {
    public let id: String
    public let displayName: String
    public let displayPrice: String

    public init(id: String, displayName: String, displayPrice: String) {
        self.id = id
        self.displayName = displayName
        self.displayPrice = displayPrice
    }
}

public enum PurchaseOutcome: Sendable {
    case granted(productID: String, transactionID: String, cash: Money?)
    case cancelled
    case pending
}

public protocol PurchaseService: Sendable {
    func products() async throws -> [CommerceProduct]
    func purchase(productID: String) async throws -> PurchaseOutcome
    func restore() async throws -> [PurchaseOutcome]
}
