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
        try requireUnique(catalog.reviews.map(\.id), kind: "Yorum")
        try requireUnique(catalog.shopLevels.map { String($0.id) }, kind: "Dükkân seviyesi")

        guard catalog.vehicles.count >= 12 else { throw ContentError.invalidValue("En az 12 araç gerekli") }
        guard catalog.faults.count >= 30 else { throw ContentError.invalidValue("En az 30 arıza gerekli") }
        guard catalog.customers.count >= 20 else { throw ContentError.invalidValue("En az 20 müşteri gerekli") }
        guard catalog.reviews.count >= 24 else { throw ContentError.invalidValue("En az 24 yorum metni gerekli") }
        guard catalog.faults.allSatisfy({ $0.inspectionFindings.count >= 2 }) else {
            throw ContentError.invalidValue("Her arıza en az iki araç kontrolüyle bağlantılı olmalı")
        }
        guard Set(catalog.faults.map(\.repairGame)).count == catalog.faults.count else {
            throw ContentError.invalidValue("Her arıza kendine özgü mini oyun kullanmalı")
        }
        guard catalog.faults.allSatisfy({ $0.complaintVariants.count >= 2 }) else {
            throw ContentError.invalidValue("Her arıza en az üç farklı müşteri anlatımına sahip olmalı")
        }
        guard catalog.customers.allSatisfy({ $0.minimumExpertise >= 1 }) else {
            throw ContentError.invalidValue("Müşteri uzmanlık açılışı en az 1 olmalı")
        }
        guard Set(catalog.faults.map(\.area)) == Set(SkillArea.allCases) else {
            throw ContentError.invalidValue("Dört uzmanlık alanının tümü içerikte bulunmalı")
        }
        guard catalog.shopLevels.map(\.id).sorted() == Array(1...7) else {
            throw ContentError.invalidValue("Dükkân seviyeleri 1 ile 7 arasında kesintisiz olmalı")
        }
        guard catalog.washLevels.map(\.id).sorted() == Array(1...3),
              catalog.washLevels.allSatisfy({ $0.requiredShopLevel >= 1 && $0.durationMinutes > 0 && $0.trustBonus > 0 }),
              zip(catalog.washLevels, catalog.washLevels.dropFirst()).allSatisfy({ current, next in
                  current.washCost >= next.washCost
              }) else {
            throw ContentError.invalidValue("Yıkama seviyeleri 1 ile 3 arasında geçerli ve artan faydalı olmalı")
        }
        guard catalog.shopLevels.allSatisfy({ $0.facilities.contains(.basicRepair) }) else {
            throw ContentError.invalidValue("Her dükkân seviyesinde temel tamir kabiliyeti bulunmalı")
        }
        guard catalog.shopLevels[1].facilities.contains(.periodicMaintenance),
              catalog.shopLevels[1].maxApprentices >= 1,
              catalog.shopLevels[2].facilities.contains(.washBay),
              catalog.shopLevels[4].facilities.contains(.bodyPaintBooth),
              catalog.shopLevels[6].facilities.contains(.vehicleShowroom) else {
            throw ContentError.invalidValue("Dükkân gelişim hattındaki hizmet alanları eksik")
        }
        let visibleDailyCost = catalog.balance.dailyRent
            + catalog.balance.dailyUtilities
            + catalog.balance.dailySupplies
        guard visibleDailyCost == catalog.balance.dailyExpense else {
            throw ContentError.invalidValue("Görünür günlük giderler toplam giderle eşleşmeli")
        }
    }

    private static func requireUnique(_ ids: [String], kind: String) throws {
        var seen = Set<String>()
        for id in ids where !seen.insert(id).inserted {
            throw ContentError.duplicateID(kind: kind, id: id)
        }
    }
}
