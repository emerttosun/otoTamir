import Foundation

public enum ApprenticeWorkPhase: String, Codable, Sendable {
    case preparation
    case waitingForPrice
    case repair
}

public struct ApprenticeWorkOrder: Codable, Hashable, Sendable {
    public let apprenticeID: UUID
    public let partQuality: PartQuality
    public var phase: ApprenticeWorkPhase
    public var completesAtMinute: Int?
    public var preparationAttempts: Int

    public init(
        apprenticeID: UUID,
        partQuality: PartQuality,
        phase: ApprenticeWorkPhase,
        completesAtMinute: Int?,
        preparationAttempts: Int = 0
    ) {
        self.apprenticeID = apprenticeID
        self.partQuality = partQuality
        self.phase = phase
        self.completesAtMinute = completesAtMinute
        self.preparationAttempts = preparationAttempts
    }
}
