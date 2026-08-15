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
            let engine: GameEngine
            let saveRepository: any SaveRepository
#if DEBUG
            if let scenarioName = ProcessInfo.processInfo.environment["OTOTAMIR_QA_SCENARIO"],
               let qaState = try QAScenarioFactory.make(named: scenarioName, catalog: catalog) {
                engine = GameEngine(state: qaState, catalog: catalog)
                saveRepository = InMemorySaveRepository(state: qaState)
            } else {
                engine = GameEngine(catalog: catalog)
                let applicationSupport = try Self.applicationSupportDirectory()
                saveRepository = JSONFileSaveRepository(directory: applicationSupport)
            }
#else
            engine = GameEngine(catalog: catalog)
            let applicationSupport = try Self.applicationSupportDirectory()
            saveRepository = JSONFileSaveRepository(directory: applicationSupport)
#endif
            let cloudSync: any CloudSyncService
#if targetEnvironment(simulator)
            cloudSync = DisabledCloudSyncService()
#else
            cloudSync = CloudKitGameSyncService(containerIdentifier: "iCloud.com.abim.OtoTamirGame")
#endif
            gameStore = GameStore(
                engine: engine,
                saveRepository: saveRepository,
                cloudSync: cloudSync,
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
