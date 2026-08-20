import GameDomain

struct PartOrderDetails: Sendable {
    let referenceID: String
    let name: String
    let baseCost: Money
    let qualityProfile: PartQualityProfile
}

public enum PartPricingRules {
    public static func replacementPart(
        for fault: FaultDefinition,
        catalog: ContentCatalog
    ) -> PartDefinition? {
        catalog.part(for: fault)
    }

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
        profile: PartQualityProfile
    ) -> Money {
        percent(baseCost, quality.costPercent(for: profile))
    }

    static func orderDetails(for job: RepairJob, catalog: ContentCatalog) -> PartOrderDetails? {
        if job.serviceKind == .periodicMaintenance {
            let parts = maintenanceParts(for: job.maintenanceTasks, catalog: catalog)
            guard !parts.isEmpty else { return nil }
            return PartOrderDetails(
                referenceID: "periodic_maintenance",
                name: parts.map(\.name).joined(separator: ", "),
                baseCost: parts.reduce(.zero) { $0 + $1.basePrice },
                qualityProfile: .maintenanceSupply
            )
        }
        guard let faultID = job.diagnosedFaultID ?? job.actualFaultID,
              let fault = catalog.fault(id: faultID),
              let part = replacementPart(for: fault, catalog: catalog) else { return nil }
        return PartOrderDetails(
            referenceID: faultID,
            name: part.name,
            baseCost: part.basePrice,
            qualityProfile: part.qualityProfile
        )
    }

    private static func percent(_ money: Money, _ value: Int) -> Money {
        Money(minorUnits: money.minorUnits * Int64(value) / 100)
    }
}
