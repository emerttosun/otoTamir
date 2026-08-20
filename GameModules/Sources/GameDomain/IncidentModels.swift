import Foundation

public enum IncidentKind: String, Codable, Sendable {
    case complaint
    case inspection
    case referral
    case loan
    case vehicleSale
    case vehiclePurchase
    case listing
    case apprentice

    public var title: String {
        switch self {
        case .complaint: "Müşteri Geri Dönüşü"
        case .inspection: "Esnaf Denetimi"
        case .referral: "Müşteri Tavsiyesi"
        case .loan: "Banka Hareketi"
        case .vehicleSale: "Araç Satışı"
        case .vehiclePurchase: "Hasarlı Araç"
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
        case .vehiclePurchase: "car.side.rear.open.fill"
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
    public let ratingImpact: Int
    public let craftsmanshipImpact: Int
    public let suspicionImpact: Int

    public init(
        id: UUID,
        sequence: Int,
        kind: IncidentKind,
        message: String,
        cashImpact: Money = .zero,
        ratingImpact: Int = 0,
        craftsmanshipImpact: Int = 0,
        suspicionImpact: Int = 0
    ) {
        self.id = id
        self.sequence = sequence
        self.kind = kind
        self.message = message
        self.cashImpact = cashImpact
        self.ratingImpact = ratingImpact
        self.craftsmanshipImpact = craftsmanshipImpact
        self.suspicionImpact = suspicionImpact
    }

    private enum CodingKeys: String, CodingKey {
        case id, sequence, kind, message, cashImpact, ratingImpact, craftsmanshipImpact, suspicionImpact
    }

    private enum LegacyCodingKeys: String, CodingKey {
        case trustImpact
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let legacyValues = try decoder.container(keyedBy: LegacyCodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        sequence = try values.decode(Int.self, forKey: .sequence)
        kind = try values.decode(IncidentKind.self, forKey: .kind)
        message = try values.decode(String.self, forKey: .message)
        cashImpact = try values.decodeIfPresent(Money.self, forKey: .cashImpact) ?? .zero
        ratingImpact = try values.decodeIfPresent(Int.self, forKey: .ratingImpact)
            ?? legacyValues.decodeIfPresent(Int.self, forKey: .trustImpact)
            ?? 0
        craftsmanshipImpact = try values.decodeIfPresent(Int.self, forKey: .craftsmanshipImpact) ?? 0
        suspicionImpact = try values.decodeIfPresent(Int.self, forKey: .suspicionImpact) ?? 0
    }
}
