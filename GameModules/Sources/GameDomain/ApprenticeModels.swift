import Foundation

public struct Apprentice: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public var level: Int
    public var experience: Int

    public init(id: UUID, name: String, level: Int = 1, experience: Int = 0) {
        self.id = id
        self.name = name
        self.level = level
        self.experience = experience
    }

    public mutating func addExperience(_ amount: Int) {
        experience += max(0, amount)
        while level < 5 && experience >= level * 100 {
            experience -= level * 100
            level += 1
        }
    }
}

