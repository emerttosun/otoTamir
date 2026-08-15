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
    public var structuralDamages: [StructuralDamage]
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
        structuralDamages: [StructuralDamage] = [],
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
        self.structuralDamages = structuralDamages
        self.mechanicalFaultIDs = mechanicalFaultIDs ?? ([visibleFaultID] + hiddenFaultIDs)
        self.airbagsDeployed = airbagsDeployed
        self.startsAndDrives = startsAndDrives
        self.recordedDamage = recordedDamage
    }

    private enum CodingKeys: String, CodingKey {
        case id, vehicleID, visibleFaultID, hiddenFaultIDs, revealedFaultIDs
        case currentBid, competitorMaximum, playerIsHighest
        case fixedPrice, severity, panelDamages, structuralDamages, mechanicalFaultIDs
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
        structuralDamages = try values.decodeIfPresent([StructuralDamage].self, forKey: .structuralDamages)
            ?? StructuralDamage.migratedFromLegacyPanels(panelDamages)
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

    public var title: String { self == .heavy ? "Onarılabilir Ağır Hasar" : "Tam Hasar • Hurda" }
}

public enum VehiclePanel: String, Codable, CaseIterable, Sendable {
    case frontBumper, hood, leftFrontFender, rightFrontFender
    case leftFrontDoor, rightFrontDoor, roof
    case leftRearDoor, rightRearDoor, leftRearFender, rightRearFender
    case trunk, rearBumper, chassis, leftPillar, rightPillar

    public static let exteriorCases: [VehiclePanel] = [
        .frontBumper, .hood, .leftFrontFender, .rightFrontFender,
        .leftFrontDoor, .rightFrontDoor, .roof,
        .leftRearDoor, .rightRearDoor, .leftRearFender, .rightRearFender,
        .trunk, .rearBumper
    ]

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
    case original, painted, replaced, damaged, heavyDamage, missing

    public var title: String {
        switch self {
        case .original: "Sağlam"
        case .painted: "Boyalı"
        case .replaced: "Değişen"
        case .damaged: "Ezik / onarılacak"
        case .heavyDamage: "Ağır ezik / kesilecek"
        case .missing: "Eksik / sökülmüş"
        }
    }
}

public enum StructuralArea: String, Codable, CaseIterable, Sendable {
    case leftFrontChassis, rightFrontChassis
    case leftPodye, rightPodye
    case leftShockTower, rightShockTower
    case leftAPillar, rightAPillar
    case leftBPillar, rightBPillar
    case leftCPillar, rightCPillar
    case frontPanel, rearPanel, trunkFloor

    public var title: String {
        switch self {
        case .leftFrontChassis: "Sol ön şasi kolu"
        case .rightFrontChassis: "Sağ ön şasi kolu"
        case .leftPodye: "Sol podye"
        case .rightPodye: "Sağ podye"
        case .leftShockTower: "Sol amortisör kulesi"
        case .rightShockTower: "Sağ amortisör kulesi"
        case .leftAPillar: "Sol A direği"
        case .rightAPillar: "Sağ A direği"
        case .leftBPillar: "Sol B direği"
        case .rightBPillar: "Sağ B direği"
        case .leftCPillar: "Sol C direği"
        case .rightCPillar: "Sağ C direği"
        case .frontPanel: "Ön panel"
        case .rearPanel: "Arka panel"
        case .trunkFloor: "Bagaj havuzu"
        }
    }
}

public enum StructuralCondition: String, Codable, Sendable {
    case intact, measurementDeviation, bent, cracked, cutOrWelded

    public var title: String {
        switch self {
        case .intact: "Sağlam • ölçü normal"
        case .measurementDeviation: "Ölçü sapması var"
        case .bent: "Eğri • doğrultma gerekli"
        case .cracked: "Çatlak / yırtık"
        case .cutOrWelded: "Kesme ve kaynak gerekli"
        }
    }

    public var requiresRepair: Bool { self != .intact }
}

public struct StructuralDamage: Codable, Hashable, Identifiable, Sendable {
    public var id: StructuralArea { area }
    public let area: StructuralArea
    public let condition: StructuralCondition

    public init(area: StructuralArea, condition: StructuralCondition) {
        self.area = area
        self.condition = condition
    }

    static func migratedFromLegacyPanels(_ panels: [PanelDamage]) -> [StructuralDamage] {
        let chassis = panels.first { $0.panel == .chassis }?.condition
        let leftPillar = panels.first { $0.panel == .leftPillar }?.condition
        let rightPillar = panels.first { $0.panel == .rightPillar }?.condition
        func structuralCondition(_ condition: PanelCondition?) -> StructuralCondition {
            switch condition {
            case .heavyDamage: .cracked
            case .damaged, .replaced: .bent
            case .painted: .measurementDeviation
            default: .intact
            }
        }
        return StructuralArea.allCases.map { area in
            let source: PanelCondition? = switch area {
            case .leftAPillar, .leftBPillar, .leftCPillar: leftPillar
            case .rightAPillar, .rightBPillar, .rightCPillar: rightPillar
            default: chassis
            }
            return StructuralDamage(area: area, condition: structuralCondition(source))
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

public struct VehicleBuyerOffer: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let buyerName: String
    public var amount: Money
    public let maximumAmount: Money
    public let createdAtMinute: Int
    public var negotiationCount: Int

    public init(
        id: UUID,
        buyerName: String,
        amount: Money,
        maximumAmount: Money,
        createdAtMinute: Int,
        negotiationCount: Int = 0
    ) {
        self.id = id
        self.buyerName = buyerName
        self.amount = amount
        self.maximumAmount = maximumAmount
        self.createdAtMinute = createdAtMinute
        self.negotiationCount = negotiationCount
    }
}

public enum ProjectRepairTask: Codable, Hashable, Identifiable, Sendable {
    case mechanical(faultID: String)
    case panel(VehiclePanel)
    case structural(StructuralArea)
    case airbag

    public var id: String {
        switch self {
        case .mechanical(let faultID): "mechanical-\(faultID)"
        case .panel(let panel): "panel-\(panel.rawValue)"
        case .structural(let area): "structural-\(area.rawValue)"
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
    public var structuralDamages: [StructuralDamage]
    public var airbagsDeployed: Bool
    public var startsAndDrives: Bool
    public var recordedDamage: Money
    public var askingPrice: Money?
    public var disclosedDamage: Bool
    public var listedAtMinute: Int?
    public var nextBuyerCheckMinute: Int?
    public var buyerOffers: [VehicleBuyerOffer]
    public var completedRepairTasks: Set<ProjectRepairTask>
    public var restorationScoreTotal: Int

    public init(
        id: UUID,
        vehicleID: String,
        faultIDs: [String],
        purchasePrice: Money,
        purchasedAtMinute: Int = 0,
        panelDamages: [PanelDamage] = [],
        structuralDamages: [StructuralDamage] = [],
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
        self.structuralDamages = structuralDamages
        self.airbagsDeployed = airbagsDeployed
        self.startsAndDrives = startsAndDrives
        self.recordedDamage = recordedDamage
        askingPrice = nil
        disclosedDamage = true
        listedAtMinute = nil
        nextBuyerCheckMinute = nil
        buyerOffers = []
        completedRepairTasks = []
        restorationScoreTotal = 0
    }

    private enum CodingKeys: String, CodingKey {
        case id, vehicleID, faultIDs, purchasePrice, purchasedAtMinute, stage, restorationQuality, restorationCost
        case panelDamages, structuralDamages, airbagsDeployed, startsAndDrives, recordedDamage
        case askingPrice, disclosedDamage, listedAtMinute, nextBuyerCheckMinute
        case buyerOffers
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
        structuralDamages = try values.decodeIfPresent([StructuralDamage].self, forKey: .structuralDamages)
            ?? StructuralDamage.migratedFromLegacyPanels(panelDamages)
        airbagsDeployed = try values.decodeIfPresent(Bool.self, forKey: .airbagsDeployed) ?? false
        startsAndDrives = try values.decodeIfPresent(Bool.self, forKey: .startsAndDrives) ?? true
        recordedDamage = try values.decodeIfPresent(Money.self, forKey: .recordedDamage) ?? .zero
        askingPrice = try values.decodeIfPresent(Money.self, forKey: .askingPrice)
        disclosedDamage = try values.decodeIfPresent(Bool.self, forKey: .disclosedDamage) ?? true
        listedAtMinute = try values.decodeIfPresent(Int.self, forKey: .listedAtMinute)
        nextBuyerCheckMinute = try values.decodeIfPresent(Int.self, forKey: .nextBuyerCheckMinute)
        buyerOffers = try values.decodeIfPresent([VehicleBuyerOffer].self, forKey: .buyerOffers) ?? []
        completedRepairTasks = try values.decodeIfPresent(Set<ProjectRepairTask>.self, forKey: .completedRepairTasks) ?? []
        restorationScoreTotal = try values.decodeIfPresent(Int.self, forKey: .restorationScoreTotal) ?? 0
    }
}
