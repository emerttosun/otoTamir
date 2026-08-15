import Foundation

public enum IncidentKind: String, Codable, Sendable {
    case complaint
    case inspection
    case referral
    case loan
    case vehicleSale
    case listing
    case apprentice

    public var title: String {
        switch self {
        case .complaint: "Müşteri Geri Dönüşü"
        case .inspection: "Esnaf Denetimi"
        case .referral: "Müşteri Tavsiyesi"
        case .loan: "Banka Hareketi"
        case .vehicleSale: "Araç Satışı"
        case .listing: "İlan Hareketi"
        case .apprentice: "Çırak İşi"
        }
    }

    public var systemImage: String {
        switch self {
        case .complaint: "exclamationmark.bubble.fill"
        case .inspection: "doc.text.magnifyingglass"
        case .referral: "person.2.fill"
        case .loan: "building.columns.fill"
        case .vehicleSale: "car.side.fill"
        case .listing: "rectangle.and.pencil.and.ellipsis"
        case .apprentice: "person.badge.clock.fill"
        }
    }
}

public struct GameIncident: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let sequence: Int
    public let kind: IncidentKind
    public let message: String
    public let cashImpact: Money
    public let trustImpact: Int
    public let craftsmanshipImpact: Int
    public let suspicionImpact: Int

    public init(
        id: UUID,
        sequence: Int,
        kind: IncidentKind,
        message: String,
        cashImpact: Money = .zero,
        trustImpact: Int = 0,
        craftsmanshipImpact: Int = 0,
        suspicionImpact: Int = 0
    ) {
        self.id = id
        self.sequence = sequence
        self.kind = kind
        self.message = message
        self.cashImpact = cashImpact
        self.trustImpact = trustImpact
        self.craftsmanshipImpact = craftsmanshipImpact
        self.suspicionImpact = suspicionImpact
    }
}
