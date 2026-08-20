import Foundation

public enum SkillArea: String, Codable, CaseIterable, Sendable {
    case engine
    case electrical
    case chassis
    case body

    public var title: String {
        switch self {
        case .engine: "Motor"
        case .electrical: "Elektrik"
        case .chassis: "Yürüyen Aksam"
        case .body: "Kaporta"
        }
    }
}

public enum RepairGameKind: String, Codable, CaseIterable, Sendable {
    case gauge
    case bolts
    case wiring
    case alignment
    case fluidFill
    case timing
    case beltTension
    case coolantBleed
    case headGasketTorque
    case batteryTerminals
    case chargingVoltage
    case sensorGap
    case brakePads
    case toeAdjustment
    case clutchCentering
    case bumperClips
    case doorGap
    case dentPull
    case sparkPlugGap
    case ignitionCoilOrder
    case injectorBalance
    case waterPumpSeal
    case timingBeltMarks
    case turboPressure
    case oilLeakTrace
    case fuseTrace
    case wireContinuity
    case windowRegulator
    case headlightAim
    case brakeDiscRunout
    case shockCompression
    case bearingPreload
    case cvBootGrease
    case hoodAlignment
    case panelWeld
    case paintLayers
}

public enum InspectionKind: String, Codable, CaseIterable, Sendable {
    case visual
    case startEngine
    case listen
    case diagnosticScanner
    case fluids
    case lift
    case wheelPlay
    case testDrive

    public var title: String {
        switch self {
        case .visual: "Gözle Kontrol"
        case .startEngine: "Motoru Çalıştır"
        case .listen: "Sesi Dinle"
        case .diagnosticScanner: "Arıza Cihazı"
        case .fluids: "Sıvıları Kontrol Et"
        case .lift: "Lifte Kaldır"
        case .wheelPlay: "Tekerlek Boşluğu"
        case .testDrive: "Test Sürüşü"
        }
    }

    public var durationMinutes: Int {
        switch self {
        case .visual: 10
        case .startEngine, .listen, .fluids: 15
        case .diagnosticScanner, .wheelPlay: 25
        case .lift: 30
        case .testDrive: 40
        }
    }
}

public struct VehicleDefinition: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let category: String
    public let baseValue: Money
    public let accentHex: String

    public init(id: String, name: String, category: String, baseValue: Money, accentHex: String) {
        self.id = id
        self.name = name
        self.category = category
        self.baseValue = baseValue
        self.accentHex = accentHex
    }
}

public struct FaultDefinition: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let area: SkillArea
    public let complaint: String
    public let complaintVariants: [String]
    public let clues: [String]
    public let inspectionFindings: [InspectionKind: String]
    public let partID: String
    public let laborValue: Money
    public let requiredSkill: Int
    public let repairGame: RepairGameKind

    public init(
        id: String,
        name: String,
        area: SkillArea,
        complaint: String,
        complaintVariants: [String] = [],
        clues: [String],
        inspectionFindings: [InspectionKind: String] = [:],
        partID: String,
        laborValue: Money,
        requiredSkill: Int,
        repairGame: RepairGameKind
    ) {
        self.id = id
        self.name = name
        self.area = area
        self.complaint = complaint
        self.complaintVariants = complaintVariants
        self.clues = clues
        self.inspectionFindings = inspectionFindings
        self.partID = partID
        self.laborValue = laborValue
        self.requiredSkill = requiredSkill
        self.repairGame = repairGame
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, area, complaint, complaintVariants, clues, inspectionFindings, partID
        case laborValue, requiredSkill, repairGame
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        area = try values.decode(SkillArea.self, forKey: .area)
        complaint = try values.decode(String.self, forKey: .complaint)
        complaintVariants = try values.decodeIfPresent([String].self, forKey: .complaintVariants) ?? []
        clues = try values.decode([String].self, forKey: .clues)
        let rawFindings = try values.decodeIfPresent([String: String].self, forKey: .inspectionFindings) ?? [:]
        inspectionFindings = Dictionary(uniqueKeysWithValues: rawFindings.compactMap { key, value in
            InspectionKind(rawValue: key).map { ($0, value) }
        })
        partID = try values.decode(String.self, forKey: .partID)
        laborValue = try values.decode(Money.self, forKey: .laborValue)
        requiredSkill = try values.decode(Int.self, forKey: .requiredSkill)
        repairGame = try values.decode(RepairGameKind.self, forKey: .repairGame)
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(name, forKey: .name)
        try values.encode(area, forKey: .area)
        try values.encode(complaint, forKey: .complaint)
        try values.encode(complaintVariants, forKey: .complaintVariants)
        try values.encode(clues, forKey: .clues)
        try values.encode(
            Dictionary(uniqueKeysWithValues: inspectionFindings.map { ($0.key.rawValue, $0.value) }),
            forKey: .inspectionFindings
        )
        try values.encode(partID, forKey: .partID)
        try values.encode(laborValue, forKey: .laborValue)
        try values.encode(requiredSkill, forKey: .requiredSkill)
        try values.encode(repairGame, forKey: .repairGame)
    }
}

public struct CustomerDefinition: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let archetype: String
    public let greeting: String
    public let priceKnowledge: Int
    public let technicalKnowledge: Int
    public let negotiationStrength: Int
    public let appearance: String
    public let profileHint: String
    public let minimumExpertise: Int

    public init(
        id: String,
        name: String,
        archetype: String,
        greeting: String,
        priceKnowledge: Int,
        technicalKnowledge: Int,
        negotiationStrength: Int,
        appearance: String = "Sade giyimli",
        profileHint: String = "Tavrından ödeme gücünü kestirmek zor",
        minimumExpertise: Int = 1
    ) {
        self.id = id
        self.name = name
        self.archetype = archetype
        self.greeting = greeting
        self.priceKnowledge = min(10, max(1, priceKnowledge))
        self.technicalKnowledge = min(10, max(1, technicalKnowledge))
        self.negotiationStrength = min(10, max(1, negotiationStrength))
        self.appearance = appearance
        self.profileHint = profileHint
        self.minimumExpertise = minimumExpertise
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, archetype, greeting, priceKnowledge, technicalKnowledge, negotiationStrength
        case appearance, profileHint, minimumExpertise
    }

    private enum LegacyCodingKeys: String, CodingKey {
        case priceSensitivity
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        archetype = try values.decode(String.self, forKey: .archetype)
        greeting = try values.decode(String.self, forKey: .greeting)
        let legacyValues = try decoder.container(keyedBy: LegacyCodingKeys.self)
        let legacyPriceKnowledge = try legacyValues.decodeIfPresent(Int.self, forKey: .priceSensitivity) ?? 5
        priceKnowledge = min(10, max(1, try values.decodeIfPresent(Int.self, forKey: .priceKnowledge) ?? legacyPriceKnowledge))
        technicalKnowledge = min(10, max(1, try values.decodeIfPresent(Int.self, forKey: .technicalKnowledge) ?? 5))
        negotiationStrength = min(10, max(1, try values.decodeIfPresent(Int.self, forKey: .negotiationStrength) ?? 5))
        appearance = try values.decodeIfPresent(String.self, forKey: .appearance) ?? "Sade giyimli"
        profileHint = try values.decodeIfPresent(String.self, forKey: .profileHint) ?? "Tavrından ödeme gücünü kestirmek zor"
        minimumExpertise = try values.decodeIfPresent(Int.self, forKey: .minimumExpertise) ?? 1
    }
}

public enum ReviewTone: String, Codable, Sendable {
    case positive
    case neutral
    case negative
}

public struct ReviewTemplateDefinition: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let tone: ReviewTone
    public let text: String

    public init(id: String, tone: ReviewTone, text: String) {
        self.id = id
        self.tone = tone
        self.text = text
    }
}

public struct ShopLevelDefinition: Codable, Hashable, Identifiable, Sendable {
    public let id: Int
    public let name: String
    public let capacity: Int
    public let upgradeCost: Money
    public let equipmentBonus: Int
    public let facilities: [ShopFacility]
    public let maxApprentices: Int

    public init(
        id: Int,
        name: String,
        capacity: Int,
        upgradeCost: Money,
        equipmentBonus: Int,
        facilities: [ShopFacility] = [.basicRepair],
        maxApprentices: Int = 0
    ) {
        self.id = id
        self.name = name
        self.capacity = capacity
        self.upgradeCost = upgradeCost
        self.equipmentBonus = equipmentBonus
        self.facilities = facilities
        self.maxApprentices = maxApprentices
    }
}

public struct WashLevelDefinition: Codable, Hashable, Identifiable, Sendable {
    public let id: Int
    public let name: String
    public let upgradeCost: Money
    public let requiredShopLevel: Int
    public let washCost: Money
    public let durationMinutes: Int
    public let trustBonus: Int
    public let detail: String

    public init(
        id: Int,
        name: String,
        upgradeCost: Money,
        requiredShopLevel: Int,
        washCost: Money,
        durationMinutes: Int,
        trustBonus: Int,
        detail: String
    ) {
        self.id = id
        self.name = name
        self.upgradeCost = upgradeCost
        self.requiredShopLevel = requiredShopLevel
        self.washCost = washCost
        self.durationMinutes = durationMinutes
        self.trustBonus = trustBonus
        self.detail = detail
    }
}

public struct BalanceDefinition: Codable, Hashable, Sendable {
    public let startingCash: Money
    public let daySlots: Int
    public let dailyExpense: Money
    public let inspectionCost: Money
    public let dailyRent: Money
    public let dailyUtilities: Money
    public let dailySupplies: Money
    public let apprenticeHireCost: Money
    public let apprenticeAdCost: Money
    public let apprenticeDailyWage: Money
    public let apprenticeBonusCost: Money

    public init(
        startingCash: Money,
        daySlots: Int,
        dailyExpense: Money,
        inspectionCost: Money,
        dailyRent: Money = Money(minorUnits: 75_000),
        dailyUtilities: Money = Money(minorUnits: 30_000),
        dailySupplies: Money = Money(minorUnits: 20_000),
        apprenticeHireCost: Money = Money(minorUnits: 750_000),
        apprenticeAdCost: Money = Money(minorUnits: 50_000),
        apprenticeDailyWage: Money = Money(minorUnits: 90_000),
        apprenticeBonusCost: Money = Money(minorUnits: 125_000)
    ) {
        self.startingCash = startingCash
        self.daySlots = daySlots
        self.dailyExpense = dailyExpense
        self.inspectionCost = inspectionCost
        self.dailyRent = dailyRent
        self.dailyUtilities = dailyUtilities
        self.dailySupplies = dailySupplies
        self.apprenticeHireCost = apprenticeHireCost
        self.apprenticeAdCost = apprenticeAdCost
        self.apprenticeDailyWage = apprenticeDailyWage
        self.apprenticeBonusCost = apprenticeBonusCost
    }
}

public struct ContentCatalog: Codable, Hashable, Sendable {
    public let vehicles: [VehicleDefinition]
    public let faults: [FaultDefinition]
    public let parts: [PartDefinition]
    public let maintenanceServices: [MaintenanceServiceDefinition]
    public let customers: [CustomerDefinition]
    public let reviews: [ReviewTemplateDefinition]
    public let shopLevels: [ShopLevelDefinition]
    public let washLevels: [WashLevelDefinition]
    public let balance: BalanceDefinition

    public init(
        vehicles: [VehicleDefinition],
        faults: [FaultDefinition],
        parts: [PartDefinition] = [],
        maintenanceServices: [MaintenanceServiceDefinition] = [],
        customers: [CustomerDefinition],
        reviews: [ReviewTemplateDefinition] = [],
        shopLevels: [ShopLevelDefinition],
        washLevels: [WashLevelDefinition] = [],
        balance: BalanceDefinition
    ) {
        self.vehicles = vehicles
        self.faults = faults
        self.parts = parts
        self.maintenanceServices = maintenanceServices
        self.customers = customers
        self.reviews = reviews
        self.shopLevels = shopLevels
        self.washLevels = washLevels
        self.balance = balance
    }

    public func vehicle(id: String) -> VehicleDefinition? { vehicles.first { $0.id == id } }
    public func fault(id: String) -> FaultDefinition? { faults.first { $0.id == id } }
    public func part(id: String) -> PartDefinition? { parts.first { $0.id == id } }
    public func part(for fault: FaultDefinition) -> PartDefinition? { part(id: fault.partID) }
    public func maintenanceService(for task: MaintenanceTask) -> MaintenanceServiceDefinition? {
        maintenanceServices.first { $0.task == task }
    }
    public func customer(id: String) -> CustomerDefinition? { customers.first { $0.id == id } }
    public func shopLevel(_ id: Int) -> ShopLevelDefinition? { shopLevels.first { $0.id == id } }
    public func washLevel(_ id: Int) -> WashLevelDefinition? { washLevels.first { $0.id == id } }
}
