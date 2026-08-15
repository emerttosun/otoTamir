import Foundation

public struct GameState: Codable, Hashable, Sendable {
    public static let currentSchemaVersion = 13

    public var schemaVersion: Int
    public var saveID: UUID
    public var revision: Int
    public var parentRevision: Int?
    public var modifiedAt: Date
    public var day: Int
    public var remainingSlots: Int
    public var totalMinutes: Int
    public var nextCustomerArrivalMinute: Int
    public var cash: Money
    public var skills: [SkillArea: Int]
    public var expertise: [SkillArea: SkillProgress]
    public var reputation: Reputation
    public var shopLevel: Int
    public var washLevel: Int
    public var offers: [CustomerOffer]
    public var activeJobs: [RepairJob]
    public var inventory: [InventoryItem]
    public var consequences: [ScheduledConsequence]
    public var auction: AuctionState?
    public var projectCars: [ProjectCar]
    public var reviews: [ShopReview]
    public var ratingTenths: Int
    public var apprentices: [Apprentice]
    public var apprenticeRecruitment: ApprenticeRecruitment?
    public var financeEntries: [FinanceEntry]
    public var loans: [BankLoan]
    public var incidents: [GameIncident]
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
        totalMinutes = 8 * 60
        nextCustomerArrivalMinute = 8 * 60 + 15
        cash = startingCash
        skills = Dictionary(uniqueKeysWithValues: SkillArea.allCases.map { ($0, 1) })
        expertise = Dictionary(uniqueKeysWithValues: SkillArea.allCases.map { ($0, SkillProgress()) })
        reputation = Reputation()
        shopLevel = 1
        washLevel = 0
        offers = []
        activeJobs = []
        inventory = []
        consequences = []
        auction = nil
        projectCars = []
        reviews = []
        ratingTenths = 40
        apprentices = []
        apprenticeRecruitment = nil
        financeEntries = []
        loans = []
        incidents = []
        processedTransactionIDs = []
        selectedThemeID = "classic"
        self.randomSeed = randomSeed
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, saveID, revision, parentRevision, modifiedAt
        case day, remainingSlots, totalMinutes, nextCustomerArrivalMinute, cash, skills, expertise, reputation, shopLevel, washLevel
        case offers, activeJobs, inventory, consequences, auction, projectCars
        case reviews, ratingTenths, apprentices, apprenticeRecruitment, financeEntries, loans, incidents
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
        totalMinutes = try values.decodeIfPresent(Int.self, forKey: .totalMinutes) ?? ((day - 1) * 1_440 + 8 * 60)
        nextCustomerArrivalMinute = try values.decodeIfPresent(Int.self, forKey: .nextCustomerArrivalMinute) ?? (totalMinutes + 30)
        cash = try values.decodeIfPresent(Money.self, forKey: .cash) ?? .zero
        skills = try values.decodeIfPresent([SkillArea: Int].self, forKey: .skills)
            ?? Dictionary(uniqueKeysWithValues: SkillArea.allCases.map { ($0, 1) })
        expertise = try values.decodeIfPresent([SkillArea: SkillProgress].self, forKey: .expertise)
            ?? Dictionary(uniqueKeysWithValues: skills.map { ($0.key, SkillProgress(level: $0.value)) })
        reputation = try values.decodeIfPresent(Reputation.self, forKey: .reputation) ?? Reputation()
        shopLevel = try values.decodeIfPresent(Int.self, forKey: .shopLevel) ?? 1
        washLevel = try values.decodeIfPresent(Int.self, forKey: .washLevel) ?? 0
        offers = try values.decodeIfPresent([CustomerOffer].self, forKey: .offers) ?? []
        activeJobs = try values.decodeIfPresent([RepairJob].self, forKey: .activeJobs) ?? []
        inventory = try values.decodeIfPresent([InventoryItem].self, forKey: .inventory) ?? []
        consequences = try values.decodeIfPresent([ScheduledConsequence].self, forKey: .consequences) ?? []
        auction = try values.decodeIfPresent(AuctionState.self, forKey: .auction)
        projectCars = try values.decodeIfPresent([ProjectCar].self, forKey: .projectCars) ?? []
        reviews = try values.decodeIfPresent([ShopReview].self, forKey: .reviews) ?? []
        ratingTenths = try values.decodeIfPresent(Int.self, forKey: .ratingTenths) ?? 40
        apprentices = try values.decodeIfPresent([Apprentice].self, forKey: .apprentices) ?? []
        apprenticeRecruitment = try values.decodeIfPresent(ApprenticeRecruitment.self, forKey: .apprenticeRecruitment)
        financeEntries = try values.decodeIfPresent([FinanceEntry].self, forKey: .financeEntries) ?? []
        loans = try values.decodeIfPresent([BankLoan].self, forKey: .loans) ?? []
        incidents = try values.decodeIfPresent([GameIncident].self, forKey: .incidents) ?? []
        processedTransactionIDs = try values.decodeIfPresent(Set<String>.self, forKey: .processedTransactionIDs) ?? []
        selectedThemeID = try values.decodeIfPresent(String.self, forKey: .selectedThemeID) ?? "classic"
        randomSeed = try values.decodeIfPresent(UInt64.self, forKey: .randomSeed) ?? 0x0A70_7A11
    }

    public var minuteOfDay: Int { totalMinutes % 1_440 }

    public var clockText: String {
        String(format: "%02d:%02d", minuteOfDay / 60, minuteOfDay % 60)
    }

    public var shopRatingText: String {
        String(format: "%.1f", Double(ratingTenths) / 10)
    }
}
