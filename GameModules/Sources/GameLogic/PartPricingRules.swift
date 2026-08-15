import GameDomain

public enum PartPricingRules {
    public static func maintenanceParts(
        for tasks: [MaintenanceTask],
        catalog: ContentCatalog
    ) -> [PartDefinition] {
        var seen = Set<String>()
        return tasks.flatMap { catalog.maintenanceService(for: $0)?.partIDs ?? [] }
            .compactMap { id -> PartDefinition? in
                guard seen.insert(id).inserted else { return nil }
                return catalog.part(id: id)
            }
    }

    public static func maintenanceBasePartCost(
        for tasks: [MaintenanceTask],
        catalog: ContentCatalog
    ) -> Money {
        maintenanceParts(for: tasks, catalog: catalog)
            .reduce(.zero) { $0 + $1.basePrice }
    }

    public static func maintenanceLaborValue(
        for tasks: [MaintenanceTask],
        catalog: ContentCatalog
    ) -> Money {
        Set(tasks).compactMap { catalog.maintenanceService(for: $0) }
            .reduce(.zero) { $0 + $1.laborValue }
    }

    public static func purchasePrice(
        baseCost: Money,
        quality: PartQuality,
        profile: PartQualityProfile,
        hasPartsStorage: Bool
    ) -> Money {
        var price = percent(baseCost, quality.costPercent(for: profile))
        if hasPartsStorage {
            price = percent(price, 90)
        }
        return price
    }

    private static func percent(_ money: Money, _ value: Int) -> Money {
        Money(minorUnits: money.minorUnits * Int64(value) / 100)
    }
}
