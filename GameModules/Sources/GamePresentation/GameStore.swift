import Foundation
import GameContent
import GameDomain
import GameLogic

@MainActor
public final class GameStore: ObservableObject {
    @Published public private(set) var state: GameState
    @Published public private(set) var products: [CommerceProduct] = []
    @Published public var bannerMessage: String?
    @Published public var errorMessage: String?
    @Published public var cloudConflict: (local: GameState, remote: GameState)?
    @Published public private(set) var isBusy = false

    public let catalog: ContentCatalog
    private var engine: GameEngine
    private let saveRepository: any SaveRepository
    private let cloudSync: any CloudSyncService
    private let purchaseService: any PurchaseService
    private var hasStarted = false

    public init(
        engine: GameEngine,
        saveRepository: any SaveRepository,
        cloudSync: any CloudSyncService,
        purchaseService: any PurchaseService
    ) {
        self.engine = engine
        state = engine.state
        catalog = engine.catalog
        self.saveRepository = saveRepository
        self.cloudSync = cloudSync
        self.purchaseService = purchaseService
    }

    public func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        isBusy = true
        defer { isBusy = false }
        do {
            if let saved = try await saveRepository.load() {
                engine = GameEngine(state: saved, catalog: catalog)
            }
            let events = try engine.handle(.prepareDay)
            state = engine.state
            show(events)
            try await saveRepository.save(state)
            products = (try? await purchaseService.products()) ?? []
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func send(_ command: GameCommand) {
        do {
            let events = try engine.handle(command)
            state = engine.state
            show(events)
            Task { [saveRepository, state] in
                try? await saveRepository.save(state)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func synchronizeCloud() async {
        isBusy = true
        defer { isBusy = false }
        switch await cloudSync.synchronize(local: state) {
        case .unavailable:
            bannerMessage = "iCloud şu anda kullanılamıyor; oyun yerel kayda devam ediyor."
        case .uploaded:
            bannerMessage = "Dükkân kaydı iCloud ile eşitlendi."
        case .downloaded(let remote):
            await adopt(remote)
            bannerMessage = "iCloud'daki güncel kayıt indirildi."
        case .conflict(let local, let remote):
            cloudConflict = (local, remote)
        }
    }

    public func resolveCloudConflict(useRemote: Bool) async {
        guard let conflict = cloudConflict else { return }
        cloudConflict = nil
        if useRemote {
            await adopt(conflict.remote)
        } else {
            var local = conflict.local
            local.parentRevision = conflict.remote.revision
            local.revision = max(local.revision, conflict.remote.revision) + 1
            local.modifiedAt = Date()
            await adopt(local)
            _ = await cloudSync.synchronize(local: local)
        }
    }

    public func purchase(_ product: CommerceProduct) async {
        isBusy = true
        defer { isBusy = false }
        do {
            switch try await purchaseService.purchase(productID: product.id) {
            case .granted(let productID, let transactionID, let cash):
                let theme = productID.contains("theme.copper") ? "copper" : nil
                send(.grantPurchase(transactionID: transactionID, cash: cash, themeID: theme))
            case .cancelled:
                break
            case .pending:
                bannerMessage = "Satın alma onay bekliyor."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func restorePurchases() async {
        do {
            let outcomes = try await purchaseService.restore()
            for outcome in outcomes {
                if case .granted(let productID, let transactionID, let cash) = outcome {
                    let theme = productID.contains("theme.copper") ? "copper" : nil
                    send(.grantPurchase(transactionID: transactionID, cash: cash, themeID: theme))
                }
            }
            bannerMessage = "Geri yüklenebilir satın almalar kontrol edildi."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func persistNow() async {
        try? await saveRepository.save(state)
    }

    private func adopt(_ newState: GameState) async {
        engine = GameEngine(state: newState, catalog: catalog)
        state = newState
        try? await saveRepository.save(newState)
    }

    private func show(_ events: [GameEvent]) {
        guard let event = events.last(where: { event in
            switch event {
            case .tutorial, .consequence, .diagnosisCompleted, .repairCompleted, .auctionWon, .projectCarSold, .shopUpgraded:
                true
            default:
                false
            }
        }) else { return }

        switch event {
        case .tutorial(let message), .consequence(let message):
            bannerMessage = message
        case .diagnosisCompleted(let correct):
            bannerMessage = correct
                ? "Teşhis doğru görünüyor. Şimdi müşteriye fiyat ver."
                : "Test sonuçları bu teşhisi doğrulamadı. Bir zaman dilimi gitti; tekrar düşün."
        case .repairCompleted(let quality):
            bannerMessage = "İş tamamlandı: \(quality.title)."
        case .auctionWon(let vehicle, let price):
            bannerMessage = "\(vehicle) \(price.liraText) bedelle dükkâna geliyor."
        case .projectCarSold(let price, let honest):
            bannerMessage = honest
                ? "Araç kusurları anlatılarak \(price.liraText) bedelle satıldı."
                : "Araç \(price.liraText) bedelle gitti. Telefon çalarsa şaşırma."
        case .shopUpgraded(let level):
            bannerMessage = "Dükkân \(level). seviyeye yükseldi."
        default:
            break
        }
    }
}
