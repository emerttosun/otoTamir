import GameDomain

public enum DeliveryTimingRules {
    public static func expectedDuration(
        for offer: CustomerOffer,
        catalog: ContentCatalog
    ) -> Int {
        switch offer.serviceKind {
        case .periodicMaintenance:
            return 30 + max(1, offer.maintenanceTasks.count) * 25 + 30
        case .faultRepair:
            let fault = offer.actualFaultID.flatMap(catalog.fault(id:))
            let inspectionDuration = fault?.inspectionFindings.keys
                .sorted { $0.durationMinutes < $1.durationMinutes }
                .prefix(2)
                .reduce(0) { $0 + $1.durationMinutes } ?? 40
            let repairDuration = 90 + (fault?.requiredSkill ?? 1) * 15
            return inspectionDuration + 20 + 30 + repairDuration + 30
        }
    }

    public static func status(
        currentMinute: Int,
        expectedDeliveryMinute: Int
    ) -> DeliveryTiming {
        status(delayMinutes: max(0, currentMinute - expectedDeliveryMinute))
    }

    public static func status(delayMinutes: Int) -> DeliveryTiming {
        let delay = max(0, delayMinutes)
        return switch delay {
        case 0: .onTime
        case 1 ... 120: .late
        default: .veryLate
        }
    }

    public static func scoreAdjustment(for timing: DeliveryTiming) -> Int {
        switch timing {
        case .onTime: 0
        case .late: -2
        case .veryLate: -5
        }
    }
}
