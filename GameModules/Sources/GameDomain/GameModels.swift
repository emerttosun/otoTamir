import Foundation

public enum PartQuality: String, Codable, CaseIterable, Sendable {
    case original
    case aftermarket
    case used

    public var title: String {
        switch self {
        case .original: "Orijinal"
        case .aftermarket: "Yan Sanayi"
        case .used: "Çıkma"
        }
    }

    public var costPercent: Int {
        switch self {
        case .original: 140
        case .aftermarket: 100
        case .used: 55
        }
    }

    public var reliabilityScore: Int {
        switch self {
        case .original: 95
        case .aftermarket: 78
        case .used: 48
        }
    }
}

public enum PriceStrategy: String, Codable, CaseIterable, Sendable {
    case fair
    case high
    case excessive

    public var title: String {
        switch self {
        case .fair: "Adil"
        case .high: "Yüksek"
        case .excessive: "Uçuk"
        }
    }

    public var multiplierPercent: Int {
        switch self {
        case .fair: 100
        case .high: 135
        case .excessive: 180
        }
    }
}

public enum WorkmanshipQuality: String, Codable, Sendable {
    case good
    case acceptable
    case poor

    public var title: String {
        switch self {
        case .good: "İyi işçilik"
        case .acceptable: "İdare eder"
        case .poor: "Kötü işçilik"
        }
    }
}

public enum RepairStage: String, Codable, Sendable {
    case awaitingDiagnosis
    case awaitingQuote
    case awaitingPart
    case readyForRepair
    case completed
}

public struct Reputation: Codable, Hashable, Sendable {
    public var craftsmanship: Int
    public var trust: Int
    public var suspicion: Int

    public init(craftsmanship: Int = 10, trust: Int = 10, suspicion: Int = 0) {
        self.craftsmanship = craftsmanship
        self.trust = trust
        self.suspicion = suspicion
    }

    public mutating func clamp() {
        craftsmanship = min(100, max(0, craftsmanship))
        trust = min(100, max(0, trust))
        suspicion = min(100, max(0, suspicion))
    }
}

public struct CustomerOffer: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let customerID: String
    public let vehicleID: String
    public let actualFaultID: String
    public let suspectedFaultIDs: [String]
    public let complaint: String

    public init(
        id: UUID,
        customerID: String,
        vehicleID: String,
        actualFaultID: String,
        suspectedFaultIDs: [String],
        complaint: String
    ) {
        self.id = id
        self.customerID = customerID
        self.vehicleID = vehicleID
        self.actualFaultID = actualFaultID
        self.suspectedFaultIDs = suspectedFaultIDs
        self.complaint = complaint
    }
}

public struct RepairJob: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let customerID: String
    public let vehicleID: String
    public let actualFaultID: String
    public let suspectedFaultIDs: [String]
    public var diagnosedFaultID: String?
    public var stage: RepairStage
    public var strategy: PriceStrategy?
    public var hidePartQuality: Bool
    public var quote: Money?
    public var partQuality: PartQuality?
    public var workmanship: WorkmanshipQuality?

    public init(offer: CustomerOffer) {
        id = offer.id
        customerID = offer.customerID
        vehicleID = offer.vehicleID
        actualFaultID = offer.actualFaultID
        suspectedFaultIDs = offer.suspectedFaultIDs
        diagnosedFaultID = nil
        stage = .awaitingDiagnosis
        strategy = nil
        hidePartQuality = false
        quote = nil
        partQuality = nil
        workmanship = nil
    }
}

public struct InventoryItem: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let jobID: UUID
    public let faultID: String
    public let partName: String
    public let quality: PartQuality
    public let purchasePrice: Money

    public init(
        id: UUID,
        jobID: UUID,
        faultID: String,
        partName: String,
        quality: PartQuality,
        purchasePrice: Money
    ) {
        self.id = id
        self.jobID = jobID
        self.faultID = faultID
        self.partName = partName
        self.quality = quality
        self.purchasePrice = purchasePrice
    }
}

public enum ConsequenceKind: String, Codable, Sendable {
    case complaint
    case comeback
    case inspection
    case referral
}

public struct ScheduledConsequence: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let dueDay: Int
    public let kind: ConsequenceKind
    public let amount: Money
    public let message: String

    public init(id: UUID, dueDay: Int, kind: ConsequenceKind, amount: Money, message: String) {
        self.id = id
        self.dueDay = dueDay
        self.kind = kind
        self.amount = amount
        self.message = message
    }
}

public struct AuctionLot: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let vehicleID: String
    public let visibleFaultID: String
    public let hiddenFaultIDs: [String]
    public var revealedFaultIDs: [String]
    public var currentBid: Money
    public let competitorMaximum: Money
    public var playerIsHighest: Bool

    public init(
        id: UUID,
        vehicleID: String,
        visibleFaultID: String,
        hiddenFaultIDs: [String],
        revealedFaultIDs: [String] = [],
        currentBid: Money,
        competitorMaximum: Money,
        playerIsHighest: Bool = false
    ) {
        self.id = id
        self.vehicleID = vehicleID
        self.visibleFaultID = visibleFaultID
        self.hiddenFaultIDs = hiddenFaultIDs
        self.revealedFaultIDs = revealedFaultIDs
        self.currentBid = currentBid
        self.competitorMaximum = competitorMaximum
        self.playerIsHighest = playerIsHighest
    }
}

public struct AuctionState: Codable, Hashable, Sendable {
    public var round: Int
    public var lots: [AuctionLot]

    public init(round: Int = 1, lots: [AuctionLot]) {
        self.round = round
        self.lots = lots
    }
}

public enum ProjectCarStage: String, Codable, Sendable {
    case awaitingRepair
    case readyForSale
}

public struct ProjectCar: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let vehicleID: String
    public let faultIDs: [String]
    public let purchasePrice: Money
    public var stage: ProjectCarStage
    public var restorationQuality: Int

    public init(id: UUID, vehicleID: String, faultIDs: [String], purchasePrice: Money) {
        self.id = id
        self.vehicleID = vehicleID
        self.faultIDs = faultIDs
        self.purchasePrice = purchasePrice
        stage = .awaitingRepair
        restorationQuality = 0
    }
}

public struct GameState: Codable, Hashable, Sendable {
    public static let currentSchemaVersion = 2

    public var schemaVersion: Int
    public var saveID: UUID
    public var revision: Int
    public var parentRevision: Int?
    public var modifiedAt: Date
    public var day: Int
    public var remainingSlots: Int
    public var cash: Money
    public var skills: [SkillArea: Int]
    public var reputation: Reputation
    public var shopLevel: Int
    public var offers: [CustomerOffer]
    public var activeJobs: [RepairJob]
    public var inventory: [InventoryItem]
    public var consequences: [ScheduledConsequence]
    public var auction: AuctionState?
    public var projectCars: [ProjectCar]
    public var processedTransactionIDs: Set<String>
    public var selectedThemeID: String
    public var randomSeed: UInt64

    public init(startingCash: Money, daySlots: Int, randomSeed: UInt64 = 0x0A70_7A11) {
        schemaVersion = Self.currentSchemaVersion
        saveID = UUID()
        revision = 0
        parentRevision = nil
        modifiedAt = Date()
        day = 1
        remainingSlots = daySlots
        cash = startingCash
        skills = Dictionary(uniqueKeysWithValues: SkillArea.allCases.map { ($0, 1) })
        reputation = Reputation()
        shopLevel = 1
        offers = []
        activeJobs = []
        inventory = []
        consequences = []
        auction = nil
        projectCars = []
        processedTransactionIDs = []
        selectedThemeID = "classic"
        self.randomSeed = randomSeed
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, saveID, revision, parentRevision, modifiedAt
        case day, remainingSlots, cash, skills, reputation, shopLevel
        case offers, activeJobs, inventory, consequences, auction, projectCars
        case processedTransactionIDs, selectedThemeID, randomSeed
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        saveID = try values.decodeIfPresent(UUID.self, forKey: .saveID) ?? UUID()
        revision = try values.decodeIfPresent(Int.self, forKey: .revision) ?? 0
        parentRevision = try values.decodeIfPresent(Int.self, forKey: .parentRevision)
        modifiedAt = try values.decodeIfPresent(Date.self, forKey: .modifiedAt) ?? Date()
        day = try values.decodeIfPresent(Int.self, forKey: .day) ?? 1
        remainingSlots = try values.decodeIfPresent(Int.self, forKey: .remainingSlots) ?? 8
        cash = try values.decodeIfPresent(Money.self, forKey: .cash) ?? .zero
        skills = try values.decodeIfPresent([SkillArea: Int].self, forKey: .skills)
            ?? Dictionary(uniqueKeysWithValues: SkillArea.allCases.map { ($0, 1) })
        reputation = try values.decodeIfPresent(Reputation.self, forKey: .reputation) ?? Reputation()
        shopLevel = try values.decodeIfPresent(Int.self, forKey: .shopLevel) ?? 1
        offers = try values.decodeIfPresent([CustomerOffer].self, forKey: .offers) ?? []
        activeJobs = try values.decodeIfPresent([RepairJob].self, forKey: .activeJobs) ?? []
        inventory = try values.decodeIfPresent([InventoryItem].self, forKey: .inventory) ?? []
        consequences = try values.decodeIfPresent([ScheduledConsequence].self, forKey: .consequences) ?? []
        auction = try values.decodeIfPresent(AuctionState.self, forKey: .auction)
        projectCars = try values.decodeIfPresent([ProjectCar].self, forKey: .projectCars) ?? []
        processedTransactionIDs = try values.decodeIfPresent(Set<String>.self, forKey: .processedTransactionIDs) ?? []
        selectedThemeID = try values.decodeIfPresent(String.self, forKey: .selectedThemeID) ?? "classic"
        randomSeed = try values.decodeIfPresent(UInt64.self, forKey: .randomSeed) ?? 0x0A70_7A11
    }
}
