import Foundation

public enum GameCommand: Sendable {
    case prepareDay
    case acceptOffer(UUID)
    case diagnose(jobID: UUID, faultID: String)
    case setQuote(jobID: UUID, strategy: PriceStrategy, hidePartQuality: Bool)
    case buyPart(jobID: UUID, quality: PartQuality)
    case completeRepair(jobID: UUID, performance: Int)
    case endDay
    case upgradeShop
    case inspectAuctionLot(UUID)
    case placeAuctionBid(lotID: UUID, amount: Money)
    case advanceAuctionRound
    case repairProjectCar(projectID: UUID, performance: Int)
    case sellProjectCar(projectID: UUID, honest: Bool)
    case grantPurchase(transactionID: String, cash: Money?, themeID: String?)
}

public enum GameEvent: Equatable, Sendable {
    case dayPrepared(Int)
    case offerAccepted(UUID)
    case diagnosisCompleted(correct: Bool)
    case quotePrepared(Money)
    case moneyChanged(Money, reason: String)
    case repairCompleted(WorkmanshipQuality)
    case reputationChanged(Reputation)
    case consequence(String)
    case dayEnded(Int)
    case tutorial(String)
    case shopUpgraded(Int)
    case auctionOpened
    case auctionRoundAdvanced(Int)
    case auctionWon(vehicleName: String, price: Money)
    case projectCarReady(UUID)
    case projectCarSold(price: Money, honest: Bool)
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
        case .notEnoughTime: "Bugün bu iş için yeterli zaman kalmadı."
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
