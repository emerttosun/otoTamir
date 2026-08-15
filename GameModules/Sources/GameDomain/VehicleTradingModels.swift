import Foundation

public struct AuctionLot: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let vehicleID: String
    public let visibleFaultID: String
    public let hiddenFaultIDs: [String]
    public var revealedFaultIDs: [String]
    public var currentBid: Money
    public let competitorMaximum: Money
    public var playerIsHighest: Bool
    public var fixedPrice: Money
    public var severity: SalvageSeverity
    public var panelDamages: [PanelDamage]
    public var mechanicalFaultIDs: [String]
    public var airbagsDeployed: Bool
    public var startsAndDrives: Bool
    public var recordedDamage: Money

    public init(
        id: UUID,
        vehicleID: String,
        visibleFaultID: String,
        hiddenFaultIDs: [String],
        revealedFaultIDs: [String] = [],
        currentBid: Money,
        competitorMaximum: Money,
        playerIsHighest: Bool = false,
        fixedPrice: Money? = nil,
        severity: SalvageSeverity = .heavy,
        panelDamages: [PanelDamage] = [],
        mechanicalFaultIDs: [String]? = nil,
        airbagsDeployed: Bool = true,
        startsAndDrives: Bool = false,
        recordedDamage: Money = .zero
    ) {
        self.id = id
        self.vehicleID = vehicleID
        self.visibleFaultID = visibleFaultID
        self.hiddenFaultIDs = hiddenFaultIDs
        self.revealedFaultIDs = revealedFaultIDs
        self.currentBid = currentBid
        self.competitorMaximum = competitorMaximum
        self.playerIsHighest = playerIsHighest
        self.fixedPrice = fixedPrice ?? currentBid
        self.severity = severity
        self.panelDamages = panelDamages
        self.mechanicalFaultIDs = mechanicalFaultIDs ?? ([visibleFaultID] + hiddenFaultIDs)
        self.airbagsDeployed = airbagsDeployed
        self.startsAndDrives = startsAndDrives
        self.recordedDamage = recordedDamage
    }

    private enum CodingKeys: String, CodingKey {
        case id, vehicleID, visibleFaultID, hiddenFaultIDs, revealedFaultIDs
        case currentBid, competitorMaximum, playerIsHighest
        case fixedPrice, severity, panelDamages, mechanicalFaultIDs
        case airbagsDeployed, startsAndDrives, recordedDamage
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        vehicleID = try values.decode(String.self, forKey: .vehicleID)
        visibleFaultID = try values.decode(String.self, forKey: .visibleFaultID)
        hiddenFaultIDs = try values.decodeIfPresent([String].self, forKey: .hiddenFaultIDs) ?? []
        revealedFaultIDs = try values.decodeIfPresent([String].self, forKey: .revealedFaultIDs) ?? []
        currentBid = try values.decodeIfPresent(Money.self, forKey: .currentBid) ?? .zero
        competitorMaximum = try values.decodeIfPresent(Money.self, forKey: .competitorMaximum) ?? currentBid
        playerIsHighest = try values.decodeIfPresent(Bool.self, forKey: .playerIsHighest) ?? false
        fixedPrice = try values.decodeIfPresent(Money.self, forKey: .fixedPrice) ?? currentBid
        severity = try values.decodeIfPresent(SalvageSeverity.self, forKey: .severity) ?? .heavy
        panelDamages = try values.decodeIfPresent([PanelDamage].self, forKey: .panelDamages) ?? []
        mechanicalFaultIDs = try values.decodeIfPresent([String].self, forKey: .mechanicalFaultIDs)
            ?? ([visibleFaultID] + hiddenFaultIDs)
        airbagsDeployed = try values.decodeIfPresent(Bool.self, forKey: .airbagsDeployed) ?? true
        startsAndDrives = try values.decodeIfPresent(Bool.self, forKey: .startsAndDrives) ?? false
        recordedDamage = try values.decodeIfPresent(Money.self, forKey: .recordedDamage) ?? .zero
    }
}

public enum SalvageSeverity: String, Codable, Sendable {
    case heavy
    case totalLoss

    public var title: String { self == .heavy ? "Ağır Hasarlı" : "Pert Kayıtlı" }
}

public enum VehiclePanel: String, Codable, CaseIterable, Sendable {
    case frontBumper, hood, leftFrontFender, rightFrontFender
    case leftFrontDoor, rightFrontDoor, roof
    case leftRearDoor, rightRearDoor, leftRearFender, rightRearFender
    case trunk, rearBumper, chassis, leftPillar, rightPillar

    public var title: String {
        switch self {
        case .frontBumper: "Ön tampon"
        case .hood: "Kaput"
        case .leftFrontFender: "Sol ön çamurluk"
        case .rightFrontFender: "Sağ ön çamurluk"
        case .leftFrontDoor: "Sol ön kapı"
        case .rightFrontDoor: "Sağ ön kapı"
        case .roof: "Tavan"
        case .leftRearDoor: "Sol arka kapı"
        case .rightRearDoor: "Sağ arka kapı"
        case .leftRearFender: "Sol arka çamurluk"
        case .rightRearFender: "Sağ arka çamurluk"
        case .trunk: "Bagaj kapağı"
        case .rearBumper: "Arka tampon"
        case .chassis: "Şasi / podye"
        case .leftPillar: "Sol direk"
        case .rightPillar: "Sağ direk"
        }
    }
}

public enum PanelCondition: String, Codable, Sendable {
    case original, painted, replaced, damaged, heavyDamage

    public var title: String {
        switch self {
        case .original: "Orijinal"
        case .painted: "Boyalı"
        case .replaced: "Değişen"
        case .damaged: "Hasarlı"
        case .heavyDamage: "Ağır hasarlı"
        }
    }
}

public struct PanelDamage: Codable, Hashable, Identifiable, Sendable {
    public var id: VehiclePanel { panel }
    public let panel: VehiclePanel
    public let condition: PanelCondition

    public init(panel: VehiclePanel, condition: PanelCondition) {
        self.panel = panel
        self.condition = condition
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
    case listed
}

public enum ProjectRepairTask: Codable, Hashable, Identifiable, Sendable {
    case mechanical(faultID: String)
    case panel(VehiclePanel)
    case airbag

    public var id: String {
        switch self {
        case .mechanical(let faultID): "mechanical-\(faultID)"
        case .panel(let panel): "panel-\(panel.rawValue)"
        case .airbag: "airbag"
        }
    }
}

public struct ProjectCar: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let vehicleID: String
    public let faultIDs: [String]
    public let purchasePrice: Money
    public let purchasedAtMinute: Int
    public var stage: ProjectCarStage
    public var restorationQuality: Int
    public var restorationCost: Money
    public var panelDamages: [PanelDamage]
    public var airbagsDeployed: Bool
    public var startsAndDrives: Bool
    public var recordedDamage: Money
    public var askingPrice: Money?
    public var disclosedDamage: Bool
    public var listedAtMinute: Int?
    public var nextBuyerCheckMinute: Int?
    public var completedRepairTasks: Set<ProjectRepairTask>
    public var restorationScoreTotal: Int

    public init(
        id: UUID,
        vehicleID: String,
        faultIDs: [String],
        purchasePrice: Money,
        purchasedAtMinute: Int = 0,
        panelDamages: [PanelDamage] = [],
        airbagsDeployed: Bool = false,
        startsAndDrives: Bool = true,
        recordedDamage: Money = .zero
    ) {
        self.id = id
        self.vehicleID = vehicleID
        self.faultIDs = faultIDs
        self.purchasePrice = purchasePrice
        self.purchasedAtMinute = purchasedAtMinute
        stage = .awaitingRepair
        restorationQuality = 0
        restorationCost = .zero
        self.panelDamages = panelDamages
        self.airbagsDeployed = airbagsDeployed
        self.startsAndDrives = startsAndDrives
        self.recordedDamage = recordedDamage
        askingPrice = nil
        disclosedDamage = true
        listedAtMinute = nil
        nextBuyerCheckMinute = nil
        completedRepairTasks = []
        restorationScoreTotal = 0
    }

    private enum CodingKeys: String, CodingKey {
        case id, vehicleID, faultIDs, purchasePrice, purchasedAtMinute, stage, restorationQuality, restorationCost
        case panelDamages, airbagsDeployed, startsAndDrives, recordedDamage
        case askingPrice, disclosedDamage, listedAtMinute, nextBuyerCheckMinute
        case completedRepairTasks, restorationScoreTotal
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        vehicleID = try values.decode(String.self, forKey: .vehicleID)
        faultIDs = try values.decodeIfPresent([String].self, forKey: .faultIDs) ?? []
        purchasePrice = try values.decode(Money.self, forKey: .purchasePrice)
        purchasedAtMinute = try values.decodeIfPresent(Int.self, forKey: .purchasedAtMinute) ?? 0
        stage = try values.decodeIfPresent(ProjectCarStage.self, forKey: .stage) ?? .awaitingRepair
        restorationQuality = try values.decodeIfPresent(Int.self, forKey: .restorationQuality) ?? 0
        restorationCost = try values.decodeIfPresent(Money.self, forKey: .restorationCost) ?? .zero
        panelDamages = try values.decodeIfPresent([PanelDamage].self, forKey: .panelDamages) ?? []
        airbagsDeployed = try values.decodeIfPresent(Bool.self, forKey: .airbagsDeployed) ?? false
        startsAndDrives = try values.decodeIfPresent(Bool.self, forKey: .startsAndDrives) ?? true
        recordedDamage = try values.decodeIfPresent(Money.self, forKey: .recordedDamage) ?? .zero
        askingPrice = try values.decodeIfPresent(Money.self, forKey: .askingPrice)
        disclosedDamage = try values.decodeIfPresent(Bool.self, forKey: .disclosedDamage) ?? true
        listedAtMinute = try values.decodeIfPresent(Int.self, forKey: .listedAtMinute)
        nextBuyerCheckMinute = try values.decodeIfPresent(Int.self, forKey: .nextBuyerCheckMinute)
        completedRepairTasks = try values.decodeIfPresent(Set<ProjectRepairTask>.self, forKey: .completedRepairTasks) ?? []
        restorationScoreTotal = try values.decodeIfPresent(Int.self, forKey: .restorationScoreTotal) ?? 0
    }
}

