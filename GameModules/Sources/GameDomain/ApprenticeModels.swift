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

public enum ApprenticeTrait: String, Codable, CaseIterable, Sendable {
    case hardworking
    case slowPaced
    case disciplined
    case loyal
    case entrepreneurial

    public var title: String {
        switch self {
        case .hardworking: "Çalışkan"
        case .slowPaced: "Ağırdan Alan"
        case .disciplined: "Disiplinli"
        case .loyal: "Sadık"
        case .entrepreneurial: "Girişimci"
        }
    }

    public var detail: String {
        switch self {
        case .hardworking: "Verilen işi daha kısa sürede bitirir."
        case .slowPaced: "İşleri daha uzun sürer; yoğunlukta morali çabuk düşer."
        case .disciplined: "Takım ve iş sırasına uyar, daha temiz sonuç çıkarır."
        case .loyal: "Dükkâna bağlanır ve uzun süre yanında kalmaya yatkındır."
        case .entrepreneurial: "İşi öğrendiğinde kendi dükkânını açmayı düşünebilir."
        }
    }
}

public struct ApprenticeApplication: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let background: ApprenticeBackground
    public let introduction: String
    public let startingExperience: Int
    public let startingArea: SkillArea?
    public let traits: [ApprenticeTrait]
    public let revealedTraits: [ApprenticeTrait]
    public let appliedAtMinute: Int

    public init(
        id: UUID,
        name: String,
        background: ApprenticeBackground,
        introduction: String,
        startingExperience: Int,
        startingArea: SkillArea? = nil,
        traits: [ApprenticeTrait] = [],
        revealedTraits: [ApprenticeTrait] = [],
        appliedAtMinute: Int
    ) {
        self.id = id
        self.name = name
        self.background = background
        self.introduction = introduction
        self.startingExperience = startingExperience
        self.startingArea = startingArea
        self.traits = traits
        self.revealedTraits = revealedTraits
        self.appliedAtMinute = appliedAtMinute
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, background, introduction, startingExperience, startingArea
        case traits, revealedTraits, appliedAtMinute
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        background = try values.decode(ApprenticeBackground.self, forKey: .background)
        introduction = try values.decode(String.self, forKey: .introduction)
        startingExperience = try values.decodeIfPresent(Int.self, forKey: .startingExperience) ?? 0
        startingArea = try values.decodeIfPresent(SkillArea.self, forKey: .startingArea)
        traits = try values.decodeIfPresent([ApprenticeTrait].self, forKey: .traits) ?? []
        revealedTraits = try values.decodeIfPresent([ApprenticeTrait].self, forKey: .revealedTraits) ?? []
        appliedAtMinute = try values.decode(Int.self, forKey: .appliedAtMinute)
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
    public var expertise: [SkillArea: SkillProgress]
    public let traits: [ApprenticeTrait]
    public var revealedTraits: [ApprenticeTrait]
    public var happiness: Int
    public let hiredAtMinute: Int
    public var jobsCompleted: Int
    public var washesCompleted: Int

    public init(
        id: UUID,
        name: String,
        level: Int = 1,
        experience: Int = 0,
        background: ApprenticeBackground = .selfApplication,
        expertise: [SkillArea: SkillProgress]? = nil,
        traits: [ApprenticeTrait] = [],
        revealedTraits: [ApprenticeTrait] = [],
        happiness: Int = 65,
        hiredAtMinute: Int = 0,
        jobsCompleted: Int = 0,
        washesCompleted: Int = 0
    ) {
        self.id = id
        self.name = name
        self.level = level
        self.experience = experience
        self.background = background
        self.expertise = expertise ?? Dictionary(
            uniqueKeysWithValues: SkillArea.allCases.map { ($0, SkillProgress()) }
        )
        self.traits = traits
        self.revealedTraits = revealedTraits
        self.happiness = min(100, max(0, happiness))
        self.hiredAtMinute = hiredAtMinute
        self.jobsCompleted = jobsCompleted
        self.washesCompleted = washesCompleted
    }

    public mutating func addExperience(_ amount: Int) {
        experience += max(0, amount)
        while level < 5 && experience >= level * 100 {
            experience -= level * 100
            level += 1
        }
    }

    public mutating func addExperience(area: SkillArea, amount: Int) {
        addExperience(amount)
        expertise[area, default: SkillProgress()].addExperience(amount)
    }

    public func skillLevel(for area: SkillArea) -> Int {
        expertise[area, default: SkillProgress()].level
    }

    public mutating func changeHappiness(by amount: Int) {
        happiness = min(100, max(0, happiness + amount))
    }

    public mutating func recordRepair(quality: WorkmanshipQuality) -> [ApprenticeTrait] {
        jobsCompleted += 1
        switch quality {
        case .good: changeHappiness(by: 3)
        case .acceptable: changeHappiness(by: 1)
        case .poor: changeHappiness(by: -5)
        }
        if traits.contains(.slowPaced) { changeHappiness(by: -1) }
        return revealTraitsIfNeeded()
    }

    public mutating func recordWash() -> [ApprenticeTrait] {
        washesCompleted += 1
        changeHappiness(by: traits.contains(.slowPaced) ? -1 : 1)
        return revealTraitsIfNeeded()
    }

    private mutating func revealTraitsIfNeeded() -> [ApprenticeTrait] {
        let completedDuties = jobsCompleted + washesCompleted
        let targetCount = completedDuties >= 7 ? traits.count : (completedDuties >= 3 ? min(1, traits.count) : 0)
        guard revealedTraits.count < targetCount else { return [] }
        let newlyRevealed = Array(traits.filter { !revealedTraits.contains($0) }.prefix(targetCount - revealedTraits.count))
        revealedTraits.append(contentsOf: newlyRevealed)
        return newlyRevealed
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, level, experience, background, expertise, traits, revealedTraits
        case happiness, hiredAtMinute, jobsCompleted, washesCompleted
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        let decodedLevel = try values.decodeIfPresent(Int.self, forKey: .level) ?? 1
        level = decodedLevel
        experience = try values.decodeIfPresent(Int.self, forKey: .experience) ?? 0
        background = try values.decodeIfPresent(ApprenticeBackground.self, forKey: .background) ?? .selfApplication
        expertise = try values.decodeIfPresent([SkillArea: SkillProgress].self, forKey: .expertise)
            ?? Dictionary(uniqueKeysWithValues: SkillArea.allCases.map { ($0, SkillProgress(level: decodedLevel)) })
        traits = try values.decodeIfPresent([ApprenticeTrait].self, forKey: .traits) ?? []
        revealedTraits = try values.decodeIfPresent([ApprenticeTrait].self, forKey: .revealedTraits) ?? []
        happiness = try values.decodeIfPresent(Int.self, forKey: .happiness) ?? 65
        hiredAtMinute = try values.decodeIfPresent(Int.self, forKey: .hiredAtMinute) ?? 0
        jobsCompleted = try values.decodeIfPresent(Int.self, forKey: .jobsCompleted) ?? 0
        washesCompleted = try values.decodeIfPresent(Int.self, forKey: .washesCompleted) ?? 0
    }
}
