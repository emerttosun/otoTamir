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
    case partsStorage
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
        case .partsStorage: "Parça deposu"
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

public enum RepairStage: String, Codable, Sendable {
    case awaitingInspection
    case awaitingDiagnosis
    case awaitingPart
    case readyForRepair
    case awaitingPrice
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
    public var completedMaintenanceTasks: [MaintenanceTask]
    public var performedInspections: [InspectionKind]
    public var findings: [String]
    public var candidateFaultIDs: [String]
    public var diagnosedFaultID: String?
    public var stage: RepairStage
    public var strategy: PriceStrategy?
    public var hidePartQuality: Bool
    public var quote: Money?
    public var partQuality: PartQuality?
    public var workmanship: WorkmanshipQuality?
    public var repairPerformanceTotal: Int
    public var repairPerformanceCount: Int
    public var isWashed: Bool
    public var repairedByApprenticeID: UUID?

    public init(offer: CustomerOffer) {
        id = offer.id
        customerID = offer.customerID
        vehicleID = offer.vehicleID
        serviceKind = offer.serviceKind
        actualFaultID = offer.actualFaultID
        suspectedFaultIDs = offer.suspectedFaultIDs
        maintenanceTasks = offer.maintenanceTasks
        complaint = offer.complaint
        acceptedAtMinute = offer.arrivedAtMinute
        completedMaintenanceTasks = []
        performedInspections = []
        findings = []
        candidateFaultIDs = []
        diagnosedFaultID = nil
        stage = offer.serviceKind == .periodicMaintenance ? .awaitingPart : .awaitingInspection
        strategy = nil
        hidePartQuality = false
        quote = nil
        partQuality = nil
        workmanship = nil
        repairPerformanceTotal = 0
        repairPerformanceCount = 0
        isWashed = false
        repairedByApprenticeID = nil
    }

    private enum CodingKeys: String, CodingKey {
        case id, customerID, vehicleID, serviceKind, actualFaultID, suspectedFaultIDs
        case maintenanceTasks, complaint, acceptedAtMinute, completedMaintenanceTasks, performedInspections, findings, candidateFaultIDs
        case diagnosedFaultID, stage, strategy, hidePartQuality, quote, partQuality, workmanship
        case repairPerformanceTotal, repairPerformanceCount, isWashed, repairedByApprenticeID
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
        completedMaintenanceTasks = try values.decodeIfPresent([MaintenanceTask].self, forKey: .completedMaintenanceTasks) ?? []
        performedInspections = try values.decodeIfPresent([InspectionKind].self, forKey: .performedInspections) ?? []
        findings = try values.decodeIfPresent([String].self, forKey: .findings) ?? []
        candidateFaultIDs = try values.decodeIfPresent([String].self, forKey: .candidateFaultIDs) ?? suspectedFaultIDs
        diagnosedFaultID = try values.decodeIfPresent(String.self, forKey: .diagnosedFaultID)
        let stageText = try values.decodeIfPresent(String.self, forKey: .stage)
        switch stageText {
        case "awaitingDiagnosis":
            stage = performedInspections.count >= 2 ? .awaitingDiagnosis : .awaitingInspection
        case "awaitingQuote": stage = .awaitingPart
        case "awaitingPart": stage = .awaitingPart
        case "readyForRepair": stage = .readyForRepair
        case "completed": stage = .awaitingPrice
        case .some(let value): stage = RepairStage(rawValue: value) ?? .awaitingInspection
        case nil: stage = .awaitingInspection
        }
        strategy = try values.decodeIfPresent(PriceStrategy.self, forKey: .strategy)
        hidePartQuality = try values.decodeIfPresent(Bool.self, forKey: .hidePartQuality) ?? false
        quote = try values.decodeIfPresent(Money.self, forKey: .quote)
        partQuality = try values.decodeIfPresent(PartQuality.self, forKey: .partQuality)
        workmanship = try values.decodeIfPresent(WorkmanshipQuality.self, forKey: .workmanship)
        repairPerformanceTotal = try values.decodeIfPresent(Int.self, forKey: .repairPerformanceTotal) ?? 0
        repairPerformanceCount = try values.decodeIfPresent(Int.self, forKey: .repairPerformanceCount) ?? 0
        isWashed = try values.decodeIfPresent(Bool.self, forKey: .isWashed) ?? false
        repairedByApprenticeID = try values.decodeIfPresent(UUID.self, forKey: .repairedByApprenticeID)
    }
}

public struct Apprentice: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public var level: Int
    public var experience: Int

    public init(id: UUID, name: String, level: Int = 1, experience: Int = 0) {
        self.id = id
        self.name = name
        self.level = level
        self.experience = experience
    }

    public mutating func addExperience(_ amount: Int) {
        experience += max(0, amount)
        while level < 5 && experience >= level * 100 {
            experience -= level * 100
            level += 1
        }
    }
}

public enum FinanceCategory: String, Codable, Sendable {
    case customerIncome
    case vehicleSale
    case parts
    case rent
    case utilities
    case supplies
    case wages
    case wash
    case shopUpgrade
    case salvageVehicle
    case restoration
    case fine
    case support
    case loanProceeds
    case loanPayment
    case listingFee

    public var title: String {
        switch self {
        case .customerIncome: "Müşteri ödemesi"
        case .vehicleSale: "Araç satışı"
        case .parts: "Parça alımı"
        case .rent: "Dükkân kirası"
        case .utilities: "Elektrik, su ve enerji"
        case .supplies: "Sarf ve temizlik"
        case .wages: "Çırak ücreti"
        case .wash: "Araç yıkama"
        case .shopUpgrade: "Dükkân geliştirmesi"
        case .salvageVehicle: "Hasarlı araç alımı"
        case .restoration: "Restorasyon parçaları"
        case .fine: "Ceza ve iade"
        case .support: "Esnaf desteği"
        case .loanProceeds: "Banka kredisi"
        case .loanPayment: "Kredi taksiti"
        case .listingFee: "İlan ücreti"
        }
    }
}

public enum LoanPlan: String, Codable, CaseIterable, Sendable {
    case short
    case standard
    case flexible

    public var title: String {
        switch self {
        case .short: "Kısa Vade"
        case .standard: "Dengeli"
        case .flexible: "Esnek Vade"
        }
    }

    public var installmentCount: Int {
        switch self {
        case .short: 4
        case .standard: 8
        case .flexible: 12
        }
    }

    public var installmentIntervalDays: Int {
        switch self {
        case .short: 2
        case .standard: 3
        case .flexible: 4
        }
    }

    public var interestBasisPoints: Int {
        switch self {
        case .short: 800
        case .standard: 1500
        case .flexible: 2400
        }
    }

    public var interestText: String {
        let whole = interestBasisPoints / 100
        let fraction = interestBasisPoints % 100
        return fraction == 0 ? "%\(whole)" : "%\(whole),\(fraction)"
    }
}

public struct BankLoan: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let plan: LoanPlan
    public let borrowedAmount: Money
    public let totalRepayment: Money
    public var remainingBalance: Money
    public var remainingInstallments: Int
    public let installmentAmount: Money
    public let installmentIntervalMinutes: Int
    public var nextPaymentMinute: Int

    public init(
        id: UUID,
        plan: LoanPlan,
        borrowedAmount: Money,
        totalRepayment: Money,
        installmentAmount: Money,
        nextPaymentMinute: Int
    ) {
        self.id = id
        self.plan = plan
        self.borrowedAmount = borrowedAmount
        self.totalRepayment = totalRepayment
        remainingBalance = totalRepayment
        remainingInstallments = plan.installmentCount
        self.installmentAmount = installmentAmount
        installmentIntervalMinutes = plan.installmentIntervalDays * 1_440
        self.nextPaymentMinute = nextPaymentMinute
    }
}

public struct FinanceEntry: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let day: Int
    public let category: FinanceCategory
    public let amount: Money
    public let note: String

    public init(id: UUID, day: Int, category: FinanceCategory, amount: Money, note: String) {
        self.id = id
        self.day = day
        self.category = category
        self.amount = amount
        self.note = note
    }
}

public struct ShopReview: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let customerID: String
    public let stars: Int
    public let text: String
    public let day: Int

    public init(id: UUID, customerID: String, stars: Int, text: String, day: Int) {
        self.id = id
        self.customerID = customerID
        self.stars = min(5, max(1, stars))
        self.text = text
        self.day = day
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

public struct GameState: Codable, Hashable, Sendable {
    public static let currentSchemaVersion = 6

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
    public var offers: [CustomerOffer]
    public var activeJobs: [RepairJob]
    public var inventory: [InventoryItem]
    public var consequences: [ScheduledConsequence]
    public var auction: AuctionState?
    public var projectCars: [ProjectCar]
    public var reviews: [ShopReview]
    public var ratingTenths: Int
    public var apprentices: [Apprentice]
    public var financeEntries: [FinanceEntry]
    public var loans: [BankLoan]
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
        offers = []
        activeJobs = []
        inventory = []
        consequences = []
        auction = nil
        projectCars = []
        reviews = []
        ratingTenths = 40
        apprentices = []
        financeEntries = []
        loans = []
        processedTransactionIDs = []
        selectedThemeID = "classic"
        self.randomSeed = randomSeed
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, saveID, revision, parentRevision, modifiedAt
        case day, remainingSlots, totalMinutes, nextCustomerArrivalMinute, cash, skills, expertise, reputation, shopLevel
        case offers, activeJobs, inventory, consequences, auction, projectCars
        case reviews, ratingTenths, apprentices, financeEntries, loans, processedTransactionIDs, selectedThemeID, randomSeed
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
        offers = try values.decodeIfPresent([CustomerOffer].self, forKey: .offers) ?? []
        activeJobs = try values.decodeIfPresent([RepairJob].self, forKey: .activeJobs) ?? []
        inventory = try values.decodeIfPresent([InventoryItem].self, forKey: .inventory) ?? []
        consequences = try values.decodeIfPresent([ScheduledConsequence].self, forKey: .consequences) ?? []
        auction = try values.decodeIfPresent(AuctionState.self, forKey: .auction)
        projectCars = try values.decodeIfPresent([ProjectCar].self, forKey: .projectCars) ?? []
        reviews = try values.decodeIfPresent([ShopReview].self, forKey: .reviews) ?? []
        ratingTenths = try values.decodeIfPresent(Int.self, forKey: .ratingTenths) ?? 40
        apprentices = try values.decodeIfPresent([Apprentice].self, forKey: .apprentices) ?? []
        financeEntries = try values.decodeIfPresent([FinanceEntry].self, forKey: .financeEntries) ?? []
        loans = try values.decodeIfPresent([BankLoan].self, forKey: .loans) ?? []
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
