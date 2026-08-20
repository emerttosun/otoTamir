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

    public var detail: String {
        switch self {
        case .original: "Üretici standardı • 24 ay parça garantisi • düşük tekrar arıza riski"
        case .aftermarket: "Dengeli maliyet • 12 ay parça garantisi • orta risk"
        case .used: "Sökme parça • 30 gün dükkân garantisi • yüksek belirsizlik"
        }
    }
}

public enum ShopFacility: String, Codable, CaseIterable, Sendable {
    case basicRepair
    case waitingArea
    case periodicMaintenance
    case washBay
    case apprenticeStation
    case diagnosticLab
    case bodyPaintBooth
    case detailingBay
    case vehicleShowroom

    public var title: String {
        switch self {
        case .basicRepair: "Tamir lifti"
        case .waitingArea: "Müşteri oturma alanı"
        case .periodicMaintenance: "Yıllık bakım ekipmanı"
        case .washBay: "Araç yıkama alanı"
        case .apprenticeStation: "Çırak çalışma tezgâhı"
        case .diagnosticLab: "İleri teşhis laboratuvarı"
        case .bodyPaintBooth: "Kaporta ve boya kabini"
        case .detailingBay: "Detaylı temizlik alanı"
        case .vehicleShowroom: "Araç satış vitrini"
        }
    }
}

public enum PriceStrategy: String, Codable, CaseIterable, Sendable {
    case affordable
    case fair
    case high
    case excessive

    public var title: String {
        switch self {
        case .affordable: "Uygun"
        case .fair: "Normal"
        case .high: "Yüksek"
        case .excessive: "Uçuk"
        }
    }

    public var multiplierPercent: Int {
        switch self {
        case .affordable: 85
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

public enum DeliveryTiming: String, Codable, Sendable {
    case onTime
    case late
    case veryLate
}

public enum RepairStage: String, Codable, Sendable {
    case awaitingInspection
    case awaitingDiagnosis
    case awaitingPart
    case awaitingPrice
    case negotiating
    case readyForRepair
    case apprenticeWorking
    case awaitingDelivery
}

public enum CustomerNegotiationResponse: String, Codable, CaseIterable, Sendable {
    case acceptCounter
    case meetHalfway
    case insist

    public var title: String {
        switch self {
        case .acceptCounter: "Kabul Et"
        case .meetHalfway: "Ortada Buluş"
        case .insist: "Fiyatım Bu"
        }
    }
}

public enum ServiceKind: String, Codable, Sendable {
    case faultRepair
    case periodicMaintenance

    public var title: String {
        switch self {
        case .faultRepair: "Arıza"
        case .periodicMaintenance: "Yıllık Bakım"
        }
    }
}

public enum MaintenanceTask: String, Codable, CaseIterable, Sendable {
    case oilAndFilter
    case airFilter
    case batteryTest
    case tireCheck
    case fluidCheck

    public var title: String {
        switch self {
        case .oilAndFilter: "Motor yağı ve yağ filtresi"
        case .airFilter: "Hava ve polen filtresi"
        case .batteryTest: "Akü ölçümü"
        case .tireCheck: "Lastik ve fren kontrolü"
        case .fluidCheck: "Sıvı seviyeleri"
        }
    }

    public var gameKind: RepairGameKind {
        switch self {
        case .oilAndFilter, .fluidCheck: .fluidFill
        case .airFilter: .alignment
        case .batteryTest: .wiring
        case .tireCheck: .bolts
        }
    }

    public var skillArea: SkillArea {
        switch self {
        case .batteryTest: .electrical
        case .tireCheck: .chassis
        default: .engine
        }
    }
}

public struct SkillProgress: Codable, Hashable, Sendable {
    public var level: Int
    public var experience: Int

    public init(level: Int = 1, experience: Int = 0) {
        self.level = level
        self.experience = experience
    }

    public var experienceForNextLevel: Int { level * 100 }

    public mutating func addExperience(_ amount: Int) {
        experience += max(0, amount)
        while level < 10 && experience >= experienceForNextLevel {
            experience -= experienceForNextLevel
            level += 1
        }
    }
}

public struct Reputation: Codable, Hashable, Sendable {
    public var craftsmanship: Int
    public var suspicion: Int

    public init(craftsmanship: Int = 10, suspicion: Int = 0) {
        self.craftsmanship = craftsmanship
        self.suspicion = suspicion
    }

    public mutating func clamp() {
        craftsmanship = min(100, max(0, craftsmanship))
        suspicion = min(100, max(0, suspicion))
    }
}

public struct CustomerOffer: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let customerID: String
    public let vehicleID: String
    public let serviceKind: ServiceKind
    public let actualFaultID: String?
    public let suspectedFaultIDs: [String]
    public let maintenanceTasks: [MaintenanceTask]
    public let complaint: String
    public let arrivedAtMinute: Int
    public let expiresAtMinute: Int

    public init(
        id: UUID,
        customerID: String,
        vehicleID: String,
        serviceKind: ServiceKind = .faultRepair,
        actualFaultID: String?,
        suspectedFaultIDs: [String],
        maintenanceTasks: [MaintenanceTask] = [],
        complaint: String,
        arrivedAtMinute: Int = 0,
        expiresAtMinute: Int = .max
    ) {
        self.id = id
        self.customerID = customerID
        self.vehicleID = vehicleID
        self.serviceKind = serviceKind
        self.actualFaultID = actualFaultID
        self.suspectedFaultIDs = suspectedFaultIDs
        self.maintenanceTasks = maintenanceTasks
        self.complaint = complaint
        self.arrivedAtMinute = arrivedAtMinute
        self.expiresAtMinute = expiresAtMinute
    }

    private enum CodingKeys: String, CodingKey {
        case id, customerID, vehicleID, serviceKind, actualFaultID, suspectedFaultIDs
        case maintenanceTasks, complaint, arrivedAtMinute, expiresAtMinute
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        customerID = try values.decode(String.self, forKey: .customerID)
        vehicleID = try values.decode(String.self, forKey: .vehicleID)
        serviceKind = try values.decodeIfPresent(ServiceKind.self, forKey: .serviceKind) ?? .faultRepair
        actualFaultID = try values.decodeIfPresent(String.self, forKey: .actualFaultID)
        suspectedFaultIDs = try values.decodeIfPresent([String].self, forKey: .suspectedFaultIDs) ?? []
        maintenanceTasks = try values.decodeIfPresent([MaintenanceTask].self, forKey: .maintenanceTasks) ?? []
        complaint = try values.decode(String.self, forKey: .complaint)
        arrivedAtMinute = try values.decodeIfPresent(Int.self, forKey: .arrivedAtMinute) ?? 0
        expiresAtMinute = try values.decodeIfPresent(Int.self, forKey: .expiresAtMinute) ?? .max
    }
}

public struct RepairJob: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let customerID: String
    public let vehicleID: String
    public let serviceKind: ServiceKind
    public let actualFaultID: String?
    public let suspectedFaultIDs: [String]
    public let maintenanceTasks: [MaintenanceTask]
    public let complaint: String
    public let acceptedAtMinute: Int
    public let expectedDeliveryMinute: Int
    public var completedMaintenanceTasks: [MaintenanceTask]
    public var performedInspections: [InspectionKind]
    public var findings: [String]
    public var candidateFaultIDs: [String]
    public var diagnosedFaultID: String?
    public var stage: RepairStage
    public var strategy: PriceStrategy?
    public var hidePartQuality: Bool
    public var initialQuote: Money?
    public var quote: Money?
    public var customerCounterOffer: Money?
    public var priceWasQuestioned: Bool
    public var partQuality: PartQuality?
    public var workmanship: WorkmanshipQuality?
    public var repairPerformanceTotal: Int
    public var repairPerformanceCount: Int
    public var isWashed: Bool
    public var washRatingBonus: Int
    public var repairedByApprenticeID: UUID?
    public var apprenticeWorkOrder: ApprenticeWorkOrder?

    public init(
        offer: CustomerOffer,
        acceptedAtMinute: Int? = nil,
        expectedDeliveryMinute: Int? = nil
    ) {
        id = offer.id
        customerID = offer.customerID
        vehicleID = offer.vehicleID
        serviceKind = offer.serviceKind
        actualFaultID = offer.actualFaultID
        suspectedFaultIDs = offer.suspectedFaultIDs
        maintenanceTasks = offer.maintenanceTasks
        complaint = offer.complaint
        self.acceptedAtMinute = acceptedAtMinute ?? offer.arrivedAtMinute
        self.expectedDeliveryMinute = expectedDeliveryMinute ?? ((acceptedAtMinute ?? offer.arrivedAtMinute) + 240)
        completedMaintenanceTasks = []
        performedInspections = []
        findings = []
        candidateFaultIDs = []
        diagnosedFaultID = nil
        stage = offer.serviceKind == .periodicMaintenance ? .awaitingPart : .awaitingInspection
        strategy = nil
        hidePartQuality = false
        initialQuote = nil
        quote = nil
        customerCounterOffer = nil
        priceWasQuestioned = false
        partQuality = nil
        workmanship = nil
        repairPerformanceTotal = 0
        repairPerformanceCount = 0
        isWashed = false
        washRatingBonus = 0
        repairedByApprenticeID = nil
        apprenticeWorkOrder = nil
    }

    private enum CodingKeys: String, CodingKey {
        case id, customerID, vehicleID, serviceKind, actualFaultID, suspectedFaultIDs
        case maintenanceTasks, complaint, acceptedAtMinute, expectedDeliveryMinute, completedMaintenanceTasks, performedInspections, findings, candidateFaultIDs
        case diagnosedFaultID, stage, strategy, hidePartQuality, initialQuote, quote, customerCounterOffer, priceWasQuestioned
        case partQuality, workmanship
        case repairPerformanceTotal, repairPerformanceCount, isWashed, washRatingBonus, repairedByApprenticeID
        case apprenticeWorkOrder
    }

    private enum LegacyCodingKeys: String, CodingKey {
        case washTrustBonus
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        customerID = try values.decode(String.self, forKey: .customerID)
        vehicleID = try values.decode(String.self, forKey: .vehicleID)
        serviceKind = try values.decodeIfPresent(ServiceKind.self, forKey: .serviceKind) ?? .faultRepair
        actualFaultID = try values.decodeIfPresent(String.self, forKey: .actualFaultID)
        suspectedFaultIDs = try values.decodeIfPresent([String].self, forKey: .suspectedFaultIDs) ?? []
        maintenanceTasks = try values.decodeIfPresent([MaintenanceTask].self, forKey: .maintenanceTasks) ?? []
        complaint = try values.decodeIfPresent(String.self, forKey: .complaint) ?? "Müşteri aracın kontrol edilmesini istiyor."
        acceptedAtMinute = try values.decodeIfPresent(Int.self, forKey: .acceptedAtMinute) ?? 0
        expectedDeliveryMinute = try values.decodeIfPresent(Int.self, forKey: .expectedDeliveryMinute) ?? (acceptedAtMinute + 240)
        completedMaintenanceTasks = try values.decodeIfPresent([MaintenanceTask].self, forKey: .completedMaintenanceTasks) ?? []
        performedInspections = try values.decodeIfPresent([InspectionKind].self, forKey: .performedInspections) ?? []
        findings = try values.decodeIfPresent([String].self, forKey: .findings) ?? []
        candidateFaultIDs = try values.decodeIfPresent([String].self, forKey: .candidateFaultIDs) ?? suspectedFaultIDs
        diagnosedFaultID = try values.decodeIfPresent(String.self, forKey: .diagnosedFaultID)
        strategy = try values.decodeIfPresent(PriceStrategy.self, forKey: .strategy)
        hidePartQuality = try values.decodeIfPresent(Bool.self, forKey: .hidePartQuality) ?? false
        initialQuote = try values.decodeIfPresent(Money.self, forKey: .initialQuote)
        quote = try values.decodeIfPresent(Money.self, forKey: .quote)
        customerCounterOffer = try values.decodeIfPresent(Money.self, forKey: .customerCounterOffer)
        priceWasQuestioned = try values.decodeIfPresent(Bool.self, forKey: .priceWasQuestioned) ?? false
        partQuality = try values.decodeIfPresent(PartQuality.self, forKey: .partQuality)
        workmanship = try values.decodeIfPresent(WorkmanshipQuality.self, forKey: .workmanship)
        let stageText = try values.decodeIfPresent(String.self, forKey: .stage)
        switch stageText {
        case "awaitingDiagnosis":
            stage = performedInspections.count >= 2 ? .awaitingDiagnosis : .awaitingInspection
        case "awaitingQuote": stage = .awaitingPart
        case "awaitingPart": stage = .awaitingPart
        case "awaitingPrice": stage = workmanship == nil ? .awaitingPrice : .awaitingDelivery
        case "negotiating": stage = .negotiating
        case "readyForRepair": stage = quote == nil ? .awaitingPrice : .readyForRepair
        case "apprenticeWorking": stage = .apprenticeWorking
        case "awaitingDelivery", "completed": stage = .awaitingDelivery
        case .some(let value): stage = RepairStage(rawValue: value) ?? .awaitingInspection
        case nil: stage = .awaitingInspection
        }
        repairPerformanceTotal = try values.decodeIfPresent(Int.self, forKey: .repairPerformanceTotal) ?? 0
        repairPerformanceCount = try values.decodeIfPresent(Int.self, forKey: .repairPerformanceCount) ?? 0
        isWashed = try values.decodeIfPresent(Bool.self, forKey: .isWashed) ?? false
        let legacyValues = try decoder.container(keyedBy: LegacyCodingKeys.self)
        washRatingBonus = try values.decodeIfPresent(Int.self, forKey: .washRatingBonus)
            ?? legacyValues.decodeIfPresent(Int.self, forKey: .washTrustBonus)
            ?? (isWashed ? 1 : 0)
        repairedByApprenticeID = try values.decodeIfPresent(UUID.self, forKey: .repairedByApprenticeID)
        apprenticeWorkOrder = try values.decodeIfPresent(ApprenticeWorkOrder.self, forKey: .apprenticeWorkOrder)
    }
}
