import GameDomain

public struct CustomerExperienceEvaluation: Equatable, Sendable {
    public let score: Int
    public let stars: Int
    public let tone: ReviewTone
    public let context: ReviewContext
    public let reviewChance: Int
    public let detectedPoorWork: Bool
    public let detectedConcealedPart: Bool

    public init(
        score: Int,
        stars: Int,
        tone: ReviewTone,
        context: ReviewContext,
        reviewChance: Int,
        detectedPoorWork: Bool,
        detectedConcealedPart: Bool
    ) {
        self.score = score
        self.stars = stars
        self.tone = tone
        self.context = context
        self.reviewChance = reviewChance
        self.detectedPoorWork = detectedPoorWork
        self.detectedConcealedPart = detectedConcealedPart
    }
}

public enum CustomerExperienceRules {
    public static func evaluate(
        job: RepairJob,
        customer: CustomerDefinition,
        workmanship: WorkmanshipQuality,
        partQuality: PartQuality,
        normalTotal: Money,
        random: inout SeededRandomSource
    ) -> CustomerExperienceEvaluation {
        let poorWorkDetected = workmanship == .poor
            && random.next(upperBound: 100) < technicalDetectionChance(customer.technicalKnowledge, base: 25)
        let concealedPartDetected = job.hidePartQuality
            && random.next(upperBound: 100) < technicalDetectionChance(customer.technicalKnowledge, base: 20)

        var score = workmanshipScore(workmanship, detected: poorWorkDetected)
        if partQuality == .original { score += 1 }
        if partQuality == .used, !job.hidePartQuality { score -= 1 }
        if concealedPartDetected { score -= 4 }

        let pricePenalty = priceScore(job: job, normalTotal: normalTotal)
        score += pricePenalty
        if job.isWashed { score += min(2, max(1, job.washRatingBonus)) }

        let stars: Int
        switch score {
        case ...(-4): stars = 1
        case -3 ... -2: stars = 2
        case -1 ... 0: stars = 3
        case 1 ... 2: stars = 4
        default: stars = 5
        }
        let tone: ReviewTone = stars >= 5 ? .positive : (stars <= 2 ? .negative : .neutral)
        let context = reviewContext(
            job: job,
            normalTotal: normalTotal,
            poorWorkDetected: poorWorkDetected,
            concealedPartDetected: concealedPartDetected,
            partQuality: partQuality,
            priceScore: pricePenalty,
            tone: tone
        )
        let reviewChance = stars == 5 || stars <= 2 ? 80 : 42
        return CustomerExperienceEvaluation(
            score: score,
            stars: stars,
            tone: tone,
            context: context,
            reviewChance: reviewChance,
            detectedPoorWork: poorWorkDetected,
            detectedConcealedPart: concealedPartDetected
        )
    }

    public static func technicalDetectionChance(_ technicalKnowledge: Int, base: Int) -> Int {
        min(95, base + min(10, max(1, technicalKnowledge)) * 7)
    }

    private static func workmanshipScore(_ quality: WorkmanshipQuality, detected: Bool) -> Int {
        switch quality {
        case .good: 3
        case .acceptable: 1
        case .poor: detected ? -4 : -1
        }
    }

    private static func priceScore(job: RepairJob, normalTotal: Money) -> Int {
        guard normalTotal.minorUnits > 0 else { return 0 }
        let finalPrice = job.quote ?? job.initialQuote ?? normalTotal
        if finalPrice.minorUnits <= normalTotal.minorUnits * 90 / 100 { return 1 }
        guard job.priceWasQuestioned else { return 0 }

        let finalPercent = finalPrice.minorUnits * 100 / normalTotal.minorUnits
        let initialPercent = (job.initialQuote ?? finalPrice).minorUnits * 100 / normalTotal.minorUnits
        if finalPercent > 135 { return -2 }
        if finalPercent > 110 || initialPercent >= 170 { return -1 }
        return 0
    }

    private static func reviewContext(
        job: RepairJob,
        normalTotal: Money,
        poorWorkDetected: Bool,
        concealedPartDetected: Bool,
        partQuality: PartQuality,
        priceScore: Int,
        tone: ReviewTone
    ) -> ReviewContext {
        if concealedPartDetected { return .concealedPart }
        if poorWorkDetected && priceScore < 0 { return .poorWorkAndPrice }
        if poorWorkDetected { return .poorWork }
        if job.priceWasQuestioned {
            let finalPrice = job.quote ?? job.initialQuote ?? normalTotal
            return finalPrice.minorUnits <= normalTotal.minorUnits * 110 / 100 ? .priceRecovered : .highPrice
        }
        if partQuality == .used, !job.hidePartQuality { return .disclosedUsedPart }
        if job.isWashed, tone == .positive { return .washedPositive }
        return .general
    }
}
