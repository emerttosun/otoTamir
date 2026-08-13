import GamePresentation
import SwiftUI

@main
struct OtoTamirApp: App {
    @StateObject private var container = AppContainer()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootGameView(store: container.gameStore)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase != .active else { return }
            Task { await container.gameStore.persistNow() }
        }
    }
}

