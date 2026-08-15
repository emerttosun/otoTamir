import GameDomain

public struct CustomerQuoteBreakdown: Equatable, Sendable {
    public let partCost: Money
    public let laborCost: Money

    public init(partCost: Money, laborCost: Money) {
        self.partCost = partCost
        self.laborCost = laborCost
    }

    public var normalTotal: Money {
        partCost + laborCost
    }

    public func amount(for strategy: PriceStrategy) -> Money {
        Money(
            minorUnits: normalTotal.minorUnits * Int64(strategy.multiplierPercent) / 100
        )
    }
}

public enum CustomerPricingRules {
    public static func quote(
        partCost: Money,
        for job: RepairJob,
        catalog: ContentCatalog
    ) -> CustomerQuoteBreakdown {
        CustomerQuoteBreakdown(
            partCost: partCost,
            laborCost: laborValue(for: job, catalog: catalog)
        )
    }

    public static func laborValue(
        for job: RepairJob,
        catalog: ContentCatalog
    ) -> Money {
        if job.serviceKind == .periodicMaintenance {
            return PartPricingRules.maintenanceLaborValue(
                for: job.maintenanceTasks,
                catalog: catalog
            )
        }
        guard let faultID = job.diagnosedFaultID,
              let fault = catalog.fault(id: faultID) else {
            return .zero
        }
        return fault.laborValue
    }
}
