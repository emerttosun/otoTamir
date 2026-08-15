import Foundation

public enum ApprenticeBackground: String, Codable, CaseIterable, Sendable {
    case familyReferral
    case vocationalHighSchool
    case vocationalTrainingCenter
    case selfApplication

    public var title: String {
        switch self {
        case .familyReferral: "Ailesi getirdi"
        case .vocationalHighSchool: "Meslek lisesi mezunu"
        case .vocationalTrainingCenter: "Mesleki eğitim merkezinden"
        case .selfApplication: "Kendi başvurdu"
        }
    }
}

public struct ApprenticeApplication: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let background: ApprenticeBackground
    public let introduction: String
    public let startingExperience: Int
    public let appliedAtMinute: Int

    public init(
        id: UUID,
        name: String,
        background: ApprenticeBackground,
        introduction: String,
        startingExperience: Int,
        appliedAtMinute: Int
    ) {
        self.id = id
        self.name = name
        self.background = background
        self.introduction = introduction
        self.startingExperience = startingExperience
        self.appliedAtMinute = appliedAtMinute
    }
}

public struct ApprenticeRecruitment: Codable, Hashable, Sendable {
    public var isActive: Bool
    public let postedAtMinute: Int
    public var nextApplicationMinute: Int
    public var applications: [ApprenticeApplication]

    public init(
        isActive: Bool = true,
        postedAtMinute: Int,
        nextApplicationMinute: Int,
        applications: [ApprenticeApplication] = []
    ) {
        self.isActive = isActive
        self.postedAtMinute = postedAtMinute
        self.nextApplicationMinute = nextApplicationMinute
        self.applications = applications
    }
}

public struct Apprentice: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public var level: Int
    public var experience: Int
    public let background: ApprenticeBackground

    public init(
        id: UUID,
        name: String,
        level: Int = 1,
        experience: Int = 0,
        background: ApprenticeBackground = .selfApplication
    ) {
        self.id = id
        self.name = name
        self.level = level
        self.experience = experience
        self.background = background
    }

    public mutating func addExperience(_ amount: Int) {
        experience += max(0, amount)
        while level < 5 && experience >= level * 100 {
            experience -= level * 100
            level += 1
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, level, experience, background
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        level = try values.decodeIfPresent(Int.self, forKey: .level) ?? 1
        experience = try values.decodeIfPresent(Int.self, forKey: .experience) ?? 0
        background = try values.decodeIfPresent(ApprenticeBackground.self, forKey: .background) ?? .selfApplication
    }
}
