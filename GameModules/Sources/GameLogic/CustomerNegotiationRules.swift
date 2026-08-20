import GameDomain

public enum CustomerNegotiationRules {
    public static func noticeChance(
        for strategy: PriceStrategy,
        priceKnowledge: Int
    ) -> Int {
        switch strategy {
        case .affordable, .fair:
            return 0
        case .high:
            return min(92, priceKnowledge * 6 + 16)
        case .excessive:
            return min(92, priceKnowledge * 6 + 45)
        }
    }

    public static func counterOffer(
        normalTotal: Money,
        askingPrice: Money,
        negotiationStrength: Int
    ) -> Money {
        let markup = max(0, askingPrice.minorUnits - normalTotal.minorUnits)
        let retainedMarkupPercent = max(20, 90 - min(10, max(1, negotiationStrength)) * 7)
        return Money(
            minorUnits: normalTotal.minorUnits
                + markup * Int64(retainedMarkupPercent) / 100
        )
    }

    public static func halfway(
        askingPrice: Money,
        counterOffer: Money
    ) -> Money {
        Money(minorUnits: (askingPrice.minorUnits + counterOffer.minorUnits) / 2)
    }

    public static func insistAcceptanceChance(negotiationStrength: Int) -> Int {
        max(15, 90 - min(10, max(1, negotiationStrength)) * 7)
    }
}
