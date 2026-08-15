import Foundation

public enum PartQualityProfile: String, Codable, Sendable {
    case maintenanceSupply
    case replacementPart
}

public enum PartCategory: String, Codable, CaseIterable, Sendable {
    case lubricant
    case filter
    case fluid
    case engine
    case electrical
    case brake
    case drivetrain
    case suspension
    case body
    case paint

    public var title: String {
        switch self {
        case .lubricant: "Yağ"
        case .filter: "Filtre"
        case .fluid: "Sıvı"
        case .engine: "Motor"
        case .electrical: "Elektrik"
        case .brake: "Fren"
        case .drivetrain: "Aktarma"
        case .suspension: "Yürüyen Aksam"
        case .body: "Kaporta"
        case .paint: "Boya"
        }
    }
}

public struct PartDefinition: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let category: PartCategory
    public let basePrice: Money
    public let qualityProfile: PartQualityProfile

    public init(
        id: String,
        name: String,
        category: PartCategory,
        basePrice: Money,
        qualityProfile: PartQualityProfile
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.basePrice = basePrice
        self.qualityProfile = qualityProfile
    }
}

public extension PartQuality {
    func title(for profile: PartQualityProfile) -> String {
        switch (profile, self) {
        case (.maintenanceSupply, .used): "Ekonomik"
        case (.maintenanceSupply, .aftermarket): "Standart"
        case (.maintenanceSupply, .original): "Premium"
        case (.replacementPart, .used): "Çıkma"
        case (.replacementPart, .aftermarket): "Yan Sanayi"
        case (.replacementPart, .original): "Orijinal"
        }
    }

    func costPercent(for profile: PartQualityProfile) -> Int {
        switch (profile, self) {
        case (.maintenanceSupply, .used): 85
        case (.maintenanceSupply, .aftermarket): 100
        case (.maintenanceSupply, .original): 135
        case (.replacementPart, .used): 55
        case (.replacementPart, .aftermarket): 100
        case (.replacementPart, .original): 140
        }
    }

    func reliabilityScore(for profile: PartQualityProfile) -> Int {
        switch (profile, self) {
        case (.maintenanceSupply, .used): 75
        case (.maintenanceSupply, .aftermarket): 86
        case (.maintenanceSupply, .original): 97
        case (.replacementPart, .used): 48
        case (.replacementPart, .aftermarket): 78
        case (.replacementPart, .original): 95
        }
    }

    func detail(for profile: PartQualityProfile) -> String {
        switch (profile, self) {
        case (.maintenanceSupply, .used):
            "Temel standart • uygun fiyat • kısa değişim aralığı"
        case (.maintenanceSupply, .aftermarket):
            "Dengeli marka • normal değişim aralığı • standart koruma"
        case (.maintenanceSupply, .original):
            "Üst sınıf ürün • uzun değişim aralığı • yüksek koruma"
        case (.replacementPart, .used):
            "Sökme parça • 30 gün dükkân garantisi • yüksek belirsizlik"
        case (.replacementPart, .aftermarket):
            "Dengeli maliyet • 12 ay parça garantisi • orta risk"
        case (.replacementPart, .original):
            "Üretici standardı • 24 ay parça garantisi • düşük tekrar arıza riski"
        }
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
