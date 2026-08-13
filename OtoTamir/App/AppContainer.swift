import Foundation
import GameCommerce
import GameContent
import GameDomain
import GameLogic
import GamePersistence
import GamePresentation

@MainActor
final class AppContainer: ObservableObject {
    let gameStore: GameStore

    init() {
        do {
            let catalog = try DefaultContentRepository().load()
            let engine = GameEngine(catalog: catalog)
            let applicationSupport = try Self.applicationSupportDirectory()
            gameStore = GameStore(
                engine: engine,
                saveRepository: JSONFileSaveRepository(directory: applicationSupport),
                cloudSync: CloudKitGameSyncService(),
                purchaseService: StoreKitPurchaseService()
            )
        } catch {
            fatalError("OtoTamir başlatılamadı: \(error.localizedDescription)")
        }
    }

    private static func applicationSupportDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return base.appendingPathComponent("OtoTamir", isDirectory: true)
    }
}

