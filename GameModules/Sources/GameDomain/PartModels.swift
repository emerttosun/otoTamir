import Foundation

public enum PartCategory: String, Codable, CaseIterable, Sendable {
    case lubricant
    case filter
    case fluid

    public var title: String {
        switch self {
        case .lubricant: "Yağ"
        case .filter: "Filtre"
        case .fluid: "Sıvı"
        }
    }
}

public struct PartDefinition: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let category: PartCategory
    public let basePrice: Money

    public init(id: String, name: String, category: PartCategory, basePrice: Money) {
        self.id = id
        self.name = name
        self.category = category
        self.basePrice = basePrice
    }
}

public struct MaintenanceServiceDefinition: Codable, Hashable, Identifiable, Sendable {
    public var id: String { task.rawValue }
    public let task: MaintenanceTask
    public let partIDs: [String]
    public let laborValue: Money

    public init(task: MaintenanceTask, partIDs: [String], laborValue: Money) {
        self.task = task
        self.partIDs = partIDs
        self.laborValue = laborValue
    }
}
