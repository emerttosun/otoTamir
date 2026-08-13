@preconcurrency import CloudKit
import Foundation
import GameDomain

public actor CloudKitGameSyncService: CloudSyncService {
    private let container: CKContainer
    private let database: CKDatabase
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let recordID = CKRecord.ID(recordName: "primary-save")

    public init(containerIdentifier: String? = nil) {
        let container = containerIdentifier.map(CKContainer.init(identifier:)) ?? CKContainer.default()
        self.container = container
        database = container.privateCloudDatabase
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    public func synchronize(local: GameState) async -> CloudSyncResult {
        do {
            let status = try await container.accountStatus()
            guard status == .available else { return .unavailable }

            do {
                let record = try await database.record(for: recordID)
                guard let data = record["payload"] as? Data,
                      let remote = try? decoder.decode(GameState.self, from: data) else {
                    return await upload(local, replacing: record)
                }

                if remote.revision == local.revision {
                    return remote.modifiedAt > local.modifiedAt ? .downloaded(remote) : .uploaded
                }
                if remote.parentRevision == local.revision { return .downloaded(remote) }
                if local.parentRevision == remote.revision { return await upload(local, replacing: record) }
                return .conflict(local: local, remote: remote)
            } catch let error as CKError where error.code == .unknownItem {
                return await upload(local, replacing: nil)
            }
        } catch {
            return .unavailable
        }
    }

    private func upload(_ state: GameState, replacing record: CKRecord?) async -> CloudSyncResult {
        do {
            let target = record ?? CKRecord(recordType: "GameSave", recordID: recordID)
            target["payload"] = try encoder.encode(state) as CKRecordValue
            target["revision"] = state.revision as CKRecordValue
            target["modifiedAt"] = state.modifiedAt as CKRecordValue
            _ = try await database.save(target)
            return .uploaded
        } catch {
            return .unavailable
        }
    }
}

public struct DisabledCloudSyncService: CloudSyncService {
    public init() {}
    public func synchronize(local: GameState) async -> CloudSyncResult { .unavailable }
}
