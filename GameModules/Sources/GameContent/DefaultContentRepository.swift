import Foundation
import GameDomain

public enum ContentError: LocalizedError, Equatable, Sendable {
    case resourceMissing
    case decodingFailed(String)
    case duplicateID(kind: String, id: String)
    case invalidValue(String)

    public var errorDescription: String? {
        switch self {
        case .resourceMissing: "catalog.json paket içinde bulunamadı."
        case .decodingFailed(let detail): "İçerik okunamadı: \(detail)"
        case .duplicateID(let kind, let id): "\(kind) içinde yinelenen kimlik: \(id)"
        case .invalidValue(let detail): "Geçersiz içerik değeri: \(detail)"
        }
    }
}

public struct DefaultContentRepository: ContentRepository, Sendable {
    public init() {}

    public func load() throws -> ContentCatalog {
        guard let url = Bundle.module.url(forResource: "catalog", withExtension: "json") else {
            throw ContentError.resourceMissing
        }
        do {
            let data = try Data(contentsOf: url)
            let catalog = try JSONDecoder().decode(ContentCatalog.self, from: data)
            try ContentValidator.validate(catalog)
            return catalog
        } catch let error as ContentError {
            throw error
        } catch {
            throw ContentError.decodingFailed(error.localizedDescription)
        }
    }
}

public enum ContentValidator {
    public static func validate(_ catalog: ContentCatalog) throws {
        try requireUnique(catalog.vehicles.map(\.id), kind: "Araç")
        try requireUnique(catalog.faults.map(\.id), kind: "Arıza")
        try requireUnique(catalog.customers.map(\.id), kind: "Müşteri")
        try requireUnique(catalog.shopLevels.map { String($0.id) }, kind: "Dükkân seviyesi")

        guard catalog.vehicles.count >= 6 else { throw ContentError.invalidValue("En az 6 araç gerekli") }
        guard catalog.faults.count >= 12 else { throw ContentError.invalidValue("En az 12 arıza gerekli") }
        guard catalog.customers.count >= 10 else { throw ContentError.invalidValue("En az 10 müşteri gerekli") }
        guard Set(catalog.faults.map(\.repairGame)) == Set(RepairGameKind.allCases) else {
            throw ContentError.invalidValue("Dört mini oyun türünün tümü en az bir arızada kullanılmalı")
        }
        guard Set(catalog.faults.map(\.area)) == Set(SkillArea.allCases) else {
            throw ContentError.invalidValue("Dört uzmanlık alanının tümü içerikte bulunmalı")
        }
        guard catalog.shopLevels.map(\.id).sorted() == [1, 2, 3] else {
            throw ContentError.invalidValue("Dükkân seviyeleri 1, 2 ve 3 olmalı")
        }
        guard catalog.balance.daySlots == 8 else {
            throw ContentError.invalidValue("Prototip günü 8 zaman dilimi olmalı")
        }
    }

    private static func requireUnique(_ ids: [String], kind: String) throws {
        var seen = Set<String>()
        for id in ids where !seen.insert(id).inserted {
            throw ContentError.duplicateID(kind: kind, id: id)
        }
    }
}
