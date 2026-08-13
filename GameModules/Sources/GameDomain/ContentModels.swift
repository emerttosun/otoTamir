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
    public let clues: [String]
    public let partName: String
    public let basePartCost: Money
    public let laborValue: Money
    public let requiredSkill: Int
    public let repairGame: RepairGameKind

    public init(
        id: String,
        name: String,
        area: SkillArea,
        complaint: String,
        clues: [String],
        partName: String,
        basePartCost: Money,
        laborValue: Money,
        requiredSkill: Int,
        repairGame: RepairGameKind
    ) {
        self.id = id
        self.name = name
        self.area = area
        self.complaint = complaint
        self.clues = clues
        self.partName = partName
        self.basePartCost = basePartCost
        self.laborValue = laborValue
        self.requiredSkill = requiredSkill
        self.repairGame = repairGame
    }
}

public struct CustomerDefinition: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let archetype: String
    public let greeting: String
    public let patience: Int
    public let priceSensitivity: Int

    public init(id: String, name: String, archetype: String, greeting: String, patience: Int, priceSensitivity: Int) {
        self.id = id
        self.name = name
        self.archetype = archetype
        self.greeting = greeting
        self.patience = patience
        self.priceSensitivity = priceSensitivity
    }
}

public struct ShopLevelDefinition: Codable, Hashable, Identifiable, Sendable {
    public let id: Int
    public let name: String
    public let capacity: Int
    public let upgradeCost: Money
    public let equipmentBonus: Int

    public init(id: Int, name: String, capacity: Int, upgradeCost: Money, equipmentBonus: Int) {
        self.id = id
        self.name = name
        self.capacity = capacity
        self.upgradeCost = upgradeCost
        self.equipmentBonus = equipmentBonus
    }
}

public struct BalanceDefinition: Codable, Hashable, Sendable {
    public let startingCash: Money
    public let daySlots: Int
    public let dailyExpense: Money
    public let inspectionCost: Money

    public init(startingCash: Money, daySlots: Int, dailyExpense: Money, inspectionCost: Money) {
        self.startingCash = startingCash
        self.daySlots = daySlots
        self.dailyExpense = dailyExpense
        self.inspectionCost = inspectionCost
    }
}

public struct ContentCatalog: Codable, Hashable, Sendable {
    public let vehicles: [VehicleDefinition]
    public let faults: [FaultDefinition]
    public let customers: [CustomerDefinition]
    public let shopLevels: [ShopLevelDefinition]
    public let balance: BalanceDefinition

    public init(
        vehicles: [VehicleDefinition],
        faults: [FaultDefinition],
        customers: [CustomerDefinition],
        shopLevels: [ShopLevelDefinition],
        balance: BalanceDefinition
    ) {
        self.vehicles = vehicles
        self.faults = faults
        self.customers = customers
        self.shopLevels = shopLevels
        self.balance = balance
    }

    public func vehicle(id: String) -> VehicleDefinition? { vehicles.first { $0.id == id } }
    public func fault(id: String) -> FaultDefinition? { faults.first { $0.id == id } }
    public func customer(id: String) -> CustomerDefinition? { customers.first { $0.id == id } }
    public func shopLevel(_ id: Int) -> ShopLevelDefinition? { shopLevels.first { $0.id == id } }
}

