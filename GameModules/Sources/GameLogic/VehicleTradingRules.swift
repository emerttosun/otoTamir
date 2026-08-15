import GameDomain

public struct VehicleInvestmentEstimate: Equatable, Sendable {
    public let repairLow: Money
    public let repairHigh: Money
    public let totalInvestmentLow: Money
    public let totalInvestmentHigh: Money
    public let fairSaleLow: Money
    public let fairSaleHigh: Money
    public let profitLow: Money
    public let profitHigh: Money
}

public struct VehicleListingEstimate: Equatable, Sendable {
    public let fairPrice: Money
    public let recommendedLow: Money
    public let recommendedHigh: Money
    public let saleChancePercent: Int
}

public enum VehicleTradingRules {
    public static let listingFee = Money(minorUnits: 50_000)

    public static func investmentEstimate(
        lot: AuctionLot,
        vehicle: VehicleDefinition,
        catalog: ContentCatalog,
        hasBodyPaintBooth: Bool
    ) -> VehicleInvestmentEstimate {
        let mechanical = mechanicalPartCost(for: lot.mechanicalFaultIDs, catalog: catalog)
        let body = lot.panelDamages.reduce(Money.zero) { partial, damage in
            partial + panelRepairCost(for: damage.condition, vehicleValue: vehicle.baseValue)
        }
        let structure = lot.structuralDamages.reduce(Money.zero) { partial, damage in
            partial + structuralRepairCost(for: damage.condition, vehicleValue: vehicle.baseValue)
        }
        let airbag = lot.airbagsDeployed ? percent(vehicle.baseValue, 6) : .zero
        var repairMid = percent(mechanical, 85) + body + structure + airbag
        if hasBodyPaintBooth { repairMid = percent(repairMid, 90) }
        let repairLow = percent(repairMid, 85)
        let repairHigh = percent(repairMid, 125)
        let fairSaleLow = percent(vehicle.baseValue, lot.severity == .totalLoss ? 58 : 64)
        let fairSaleHigh = percent(vehicle.baseValue, lot.severity == .totalLoss ? 76 : 84)
        let totalLow = lot.fixedPrice + repairLow
        let totalHigh = lot.fixedPrice + repairHigh
        return VehicleInvestmentEstimate(
            repairLow: repairLow,
            repairHigh: repairHigh,
            totalInvestmentLow: totalLow,
            totalInvestmentHigh: totalHigh,
            fairSaleLow: fairSaleLow,
            fairSaleHigh: fairSaleHigh,
            profitLow: fairSaleLow - totalHigh,
            profitHigh: fairSaleHigh - totalLow
        )
    }

    public static func fairPrice(project: ProjectCar, vehicle: VehicleDefinition) -> Money {
        let qualityContribution = project.restorationQuality * 30 / 100
        let historyPenalty = project.recordedDamage > vehicle.baseValue ? 4 : 0
        return percent(vehicle.baseValue, max(50, 58 + qualityContribution - historyPenalty))
    }

    public static func listingEstimate(
        project: ProjectCar,
        vehicle: VehicleDefinition,
        askingPrice: Money,
        ratingTenths: Int,
        hasShowroom: Bool,
        discloseDamage: Bool
    ) -> VehicleListingEstimate {
        let fair = fairPrice(project: project, vehicle: vehicle)
        let priceRatio = fair.minorUnits > 0 ? Int(askingPrice.minorUnits * 100 / fair.minorUnits) : 200
        let baseChance: Int
        switch priceRatio {
        case ...85: baseChance = 90
        case 86...100: baseChance = 90 - (priceRatio - 85) * 2
        case 101...115: baseChance = 60 - (priceRatio - 100) * 2
        case 116...135: baseChance = 30 - (priceRatio - 115)
        default: baseChance = 8
        }
        let ratingBonus = (ratingTenths - 35) / 2
        let showroomBonus = hasShowroom ? 10 : 0
        let disclosureAdjustment = discloseDamage ? -3 : 7
        let chance = min(95, max(5, baseChance + ratingBonus + showroomBonus + disclosureAdjustment))
        return VehicleListingEstimate(
            fairPrice: fair,
            recommendedLow: percent(fair, 94),
            recommendedHigh: percent(fair, 106),
            saleChancePercent: chance
        )
    }

    public static func restorationCost(
        project: ProjectCar,
        vehicle: VehicleDefinition,
        catalog: ContentCatalog,
        hasBodyPaintBooth: Bool
    ) -> Money {
        let mechanical = mechanicalPartCost(for: project.faultIDs, catalog: catalog)
        let body = project.panelDamages.reduce(Money.zero) { partial, damage in
            partial + panelRepairCost(for: damage.condition, vehicleValue: vehicle.baseValue)
        }
        let structure = project.structuralDamages.reduce(Money.zero) { partial, damage in
            partial + structuralRepairCost(for: damage.condition, vehicleValue: vehicle.baseValue)
        }
        let airbag = project.airbagsDeployed ? percent(vehicle.baseValue, 6) : .zero
        let total = percent(mechanical, 85) + body + structure + airbag
        return hasBodyPaintBooth ? percent(total, 90) : total
    }

    public static func repairTaskCost(
        task: ProjectRepairTask,
        project: ProjectCar,
        vehicle: VehicleDefinition,
        catalog: ContentCatalog,
        hasBodyPaintBooth: Bool
    ) -> Money {
        let cost: Money
        switch task {
        case .mechanical(let faultID):
            cost = catalog.fault(id: faultID)
                .flatMap(catalog.part(for:))
                .map { percent($0.basePrice, 85) } ?? .zero
        case .panel(let panel):
            let condition = project.panelDamages.first { $0.panel == panel }?.condition ?? .original
            cost = panelRepairCost(for: condition, vehicleValue: vehicle.baseValue)
        case .structural(let area):
            let condition = project.structuralDamages.first { $0.area == area }?.condition ?? .intact
            cost = structuralRepairCost(for: condition, vehicleValue: vehicle.baseValue)
        case .airbag:
            cost = percent(vehicle.baseValue, 6)
        }
        if hasBodyPaintBooth, case .panel = task { return percent(cost, 90) }
        return cost
    }

    private static func panelRepairCost(for condition: PanelCondition, vehicleValue: Money) -> Money {
        switch condition {
        case .original: .zero
        case .painted: percent(vehicleValue, 1)
        case .replaced: percent(vehicleValue, 2)
        case .damaged: percent(vehicleValue, 3)
        case .heavyDamage: percent(vehicleValue, 5)
        case .missing: percent(vehicleValue, 4)
        }
    }

    private static func structuralRepairCost(for condition: StructuralCondition, vehicleValue: Money) -> Money {
        switch condition {
        case .intact: .zero
        case .measurementDeviation: percent(vehicleValue, 2)
        case .bent: percent(vehicleValue, 4)
        case .cracked: percent(vehicleValue, 6)
        case .cutOrWelded: percent(vehicleValue, 8)
        }
    }

    private static func mechanicalPartCost(for faultIDs: [String], catalog: ContentCatalog) -> Money {
        faultIDs.compactMap { catalog.fault(id: $0) }
            .compactMap(catalog.part(for:))
            .reduce(.zero) { $0 + $1.basePrice }
    }

    private static func percent(_ money: Money, _ value: Int) -> Money {
        Money(minorUnits: money.minorUnits * Int64(value) / 100)
    }
}
