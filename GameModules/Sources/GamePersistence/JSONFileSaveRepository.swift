import Foundation
import GameDomain

public enum SaveError: LocalizedError, Sendable {
    case unsupportedSchema(Int)
    case corruptPrimaryAndBackup

    public var errorDescription: String? {
        switch self {
        case .unsupportedSchema(let version): "Kayıt sürümü desteklenmiyor: \(version)"
        case .corruptPrimaryAndBackup: "Ana kayıt ve yedek kayıt okunamadı."
        }
    }
}

public actor JSONFileSaveRepository: SaveRepository {
    private let saveURL: URL
    private let backupURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(directory: URL, fileName: String = "ototamir-save.json") {
        saveURL = directory.appendingPathComponent(fileName)
        backupURL = directory.appendingPathComponent("\(fileName).backup")
        encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    public func load() async throws -> GameState? {
        guard FileManager.default.fileExists(atPath: saveURL.path) else { return nil }
        do {
            return try decodeAndMigrate(Data(contentsOf: saveURL))
        } catch {
            guard FileManager.default.fileExists(atPath: backupURL.path) else { throw error }
            do {
                return try decodeAndMigrate(Data(contentsOf: backupURL))
            } catch {
                throw SaveError.corruptPrimaryAndBackup
            }
        }
    }

    public func save(_ state: GameState) async throws {
        try FileManager.default.createDirectory(
            at: saveURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try encoder.encode(state)
        if FileManager.default.fileExists(atPath: saveURL.path) {
            if FileManager.default.fileExists(atPath: backupURL.path) {
                try? FileManager.default.removeItem(at: backupURL)
            }
            try? FileManager.default.copyItem(at: saveURL, to: backupURL)
        }
        try data.write(to: saveURL, options: [.atomic, .completeFileProtectionUnlessOpen])
    }

    private func decodeAndMigrate(_ data: Data) throws -> GameState {
        let state = try decoder.decode(GameState.self, from: data)
        guard state.schemaVersion <= GameState.currentSchemaVersion else {
            throw SaveError.unsupportedSchema(state.schemaVersion)
        }
        return SaveMigrator.migrate(state)
    }
}

enum SaveMigrator {
    static func migrate(_ source: GameState) -> GameState {
        var state = source
        if state.schemaVersion < 2 {
            state.inventory = []
            state.schemaVersion = 2
        }
        if state.schemaVersion < 3 {
            state.totalMinutes = (max(1, state.day) - 1) * 1_440 + 8 * 60
            state.nextCustomerArrivalMinute = state.totalMinutes + 30
            state.expertise = Dictionary(uniqueKeysWithValues: SkillArea.allCases.map { area in
                (area, SkillProgress(level: state.skills[area, default: 1]))
            })
            state.reviews = []
            state.ratingTenths = 40
            state.schemaVersion = 3
        }
        if state.schemaVersion < 4 {
            state.apprentices = []
            state.financeEntries = []
            state.schemaVersion = 4
        }
        if state.schemaVersion < 5 {
            state.loans = []
            state.schemaVersion = 5
        }
        if state.schemaVersion < 6 {
            state.schemaVersion = 6
        }
        if state.schemaVersion < 7 {
            state.incidents = []
            state.schemaVersion = 7
        }
        return state
    }
}

public actor InMemorySaveRepository: SaveRepository {
    private var stored: GameState?

    public init(state: GameState? = nil) {
        stored = state
    }

    public func load() async throws -> GameState? { stored }
    public func save(_ state: GameState) async throws { stored = state }
}
