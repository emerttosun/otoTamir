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
    @Published public private(set) var cloudStatus = "Yerel kayıt etkin"

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
            let events = try engine.handle(.prepareWorld)
            state = engine.state
            show(events)
            try await saveRepository.save(state)
            products = (try? await purchaseService.products()) ?? []
            Task { await synchronizeCloud(silent: true) }
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
            if state.revision.isMultiple(of: 12) {
                Task { await synchronizeCloud(silent: true) }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func synchronizeCloud(silent: Bool = false) async {
        isBusy = true
        defer { isBusy = false }
        switch await cloudSync.synchronize(local: state) {
        case .unavailable:
            cloudStatus = "Yerel kayıt • iCloud kullanılamıyor"
            if !silent { bannerMessage = "iCloud kullanılamıyor; oyun yerel kayda devam ediyor." }
        case .uploaded:
            cloudStatus = "iCloud ile güncel"
            if !silent { bannerMessage = "Dükkân kaydı iCloud ile eşitlendi." }
        case .downloaded(let remote):
            await adopt(remote)
            cloudStatus = "iCloud kaydı indirildi"
            if !silent { bannerMessage = "iCloud'daki güncel kayıt indirildi." }
        case .conflict(let local, let remote):
            cloudStatus = "Kayıt seçimi gerekiyor"
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
            case .tutorial, .consequence, .inspectionCompleted, .diagnosisCompleted, .repairCompleted,
                 .customerCountered, .customerPriceAccepted, .customerWalkedAway,
                 .priceSettled, .vehicleWashed, .apprenticeHired, .apprenticeApplicationReceived,
                 .apprenticeApplicationRejected, .apprenticeAssigned, .apprenticePreparationDelayed,
                 .apprenticeReadyForPrice, .apprenticeCompleted, .apprenticeWashed,
                 .apprenticeTraitRevealed, .apprenticeHappinessChanged,
                 .apprenticeDepartureWarning, .apprenticeStayed, .apprenticeLeft,
                 .experienceGained, .reviewReceived, .auctionWon, .projectCarSold, .shopUpgraded:
                true
            case .projectRepairCompleted, .projectCarListed, .projectListingExpired,
                 .loanTaken, .loanInstallmentPaid, .loanClosed:
                true
            default:
                false
            }
        }) else { return }

        switch event {
        case .tutorial(let message), .consequence(let message):
            bannerMessage = message
        case .inspectionCompleted(_, let finding):
            bannerMessage = "Kontrol sonucu: \(finding)"
        case .diagnosisCompleted(let correct):
            bannerMessage = correct
                ? "Teşhis doğru. Şimdi parçacıdan parçayı seç."
                : "Test sonuçları bu teşhisi doğrulamadı. 20 dakika geçti; bulguları tekrar düşün."
        case .repairCompleted(let quality):
            bannerMessage = "İş tamamlandı: \(quality.title). Araç teslime hazır."
        case .customerCountered(let askingPrice, let counterOffer):
            bannerMessage = "\(askingPrice.liraText) müşteriye yüksek geldi; \(counterOffer.liraText) teklif etti."
        case .customerPriceAccepted(let price):
            bannerMessage = "\(price.liraText) üzerinde anlaşıldı. Şimdi tamire başlayabilirsin."
        case .customerWalkedAway(let refund, let deduction):
            bannerMessage = "Müşteri fiyatı kabul etmedi. Parça iade edildi: \(refund.liraText) kasaya döndü, \(deduction.liraText) kesildi."
        case .priceSettled(let price, let reaction):
            bannerMessage = "\(price.liraText) alındı. \(reaction)"
        case .vehicleWashed:
            bannerMessage = "Araç yıkandı. Temiz teslim müşteri memnuniyetine katkı sağlayacak."
        case .apprenticeHired(let apprentice):
            bannerMessage = "\(apprentice.name) çırak olarak dükkâna katıldı. İş verdikçe tecrübe kazanacak."
        case .apprenticeApplicationReceived(let application):
            bannerMessage = "Çırak ilanına \(application.name) başvurdu: \(application.background.title)."
        case .apprenticeApplicationRejected(let name):
            bannerMessage = "\(name) adlı adayın çırak başvurusu reddedildi."
        case .apprenticeAssigned(let name, _):
            bannerMessage = "\(name) işi aldı. Çalışırken sen başka araçlarla ilgilenebilirsin."
        case .apprenticePreparationDelayed(let name, _):
            bannerMessage = "\(name) ilk kontrolde emin olamadı; 30 dakika daha ölçüm yapacak."
        case .apprenticeReadyForPrice(let name):
            bannerMessage = "\(name) kontrolü, teşhisi ve parça siparişini tamamladı. Müşteriye fiyatı sen söyleyeceksin."
        case .apprenticeCompleted(let name, let quality):
            bannerMessage = "\(name) verilen işi tamamladı: \(quality.title)."
        case .apprenticeWashed(let name):
            bannerMessage = "\(name) aracı yıkayıp teslime hazırladı ve tecrübe kazandı."
        case .apprenticeTraitRevealed(let name, let trait):
            bannerMessage = "\(name) ile çalıştıkça yeni bir özelliğini öğrendin: \(trait.title)."
        case .apprenticeHappinessChanged(let name, let happiness):
            bannerMessage = "\(name) mutluluk: %\(happiness)."
        case .apprenticeDepartureWarning(let name):
            bannerMessage = "\(name) kendi dükkânını açmayı düşünüyor. İki gün içinde mutluluğunu %80'e çıkarırsan kalmayı seçebilir."
        case .apprenticeStayed(let name):
            bannerMessage = "\(name) dükkânda kalmaya karar verdi."
        case .apprenticeLeft(let name, let customersTaken):
            bannerMessage = customersTaken > 0
                ? "\(name) kendi yerini açtı ve \(customersTaken) müşteriyi yanında götürdü."
                : "\(name) kendi yerini açmak için dükkândan ayrıldı."
        case .experienceGained(let area, let amount, let level):
            bannerMessage = "\(area.title) +\(amount) XP • Seviye \(level)"
        case .reviewReceived(let review):
            bannerMessage = "Yeni dükkân yorumu: \(String(repeating: "★", count: review.stars)) \(review.text)"
        case .auctionWon(let vehicle, let price):
            bannerMessage = "\(vehicle) \(price.liraText) bedelle dükkâna geliyor."
        case .projectRepairCompleted(_, let task):
            switch task {
            case .mechanical(let faultID):
                let partName = catalog.fault(id: faultID).flatMap(catalog.part(for:))?.name ?? "Mekanik iş"
                bannerMessage = "\(partName) tamamlandı. Sıradaki eksiği seç."
            case .panel(let panel):
                bannerMessage = "\(panel.title) işi tamamlandı. Sıradaki eksiği seç."
            case .structural(let area):
                bannerMessage = "\(area.title) yapısal onarımı tamamlandı. Sıradaki eksiği seç."
            case .airbag:
                bannerMessage = "Hava yastığı sistemi tamamlandı. Sıradaki eksiği seç."
            }
        case .projectCarSold(let price, let honest):
            bannerMessage = honest
                ? "Araç kusurları anlatılarak \(price.liraText) bedelle satıldı."
                : "Araç \(price.liraText) bedelle gitti. Telefon çalarsa şaşırma."
        case .projectCarListed(let price, let chance):
            bannerMessage = "İlan \(price.liraText) fiyatla yayında. İlk alıcı kontrolündeki tahmini satış ihtimali %\(chance)."
        case .projectListingExpired:
            bannerMessage = "İlanı görenler oldu ama bu kontrolde ciddi bir alıcı çıkmadı. Fiyatı değiştirebilir veya bekleyebilirsin."
        case .buyerOffersReceived(_, let count):
            bannerMessage = "İlana \(count) yeni teklif geldi. Kabul edebilir, reddedebilir veya pazarlık yapabilirsin."
        case .buyerOfferRejected(let name):
            bannerMessage = "\(name) adlı alıcının teklifi reddedildi."
        case .buyerNegotiationUpdated(let name, let price):
            bannerMessage = "\(name) pazarlıkta \(price.liraText) bedeli kabul etti. Satış için son karar sende."
        case .buyerWalkedAway(let name):
            bannerMessage = "Karşı teklif \(name) için yüksek kaldı; alıcı pazarlıktan çekildi."
        case .loanTaken(let amount, let total):
            bannerMessage = "Bankadan \(amount.liraText) geldi. Vade sonunda toplam geri ödeme \(total.liraText)."
        case .loanInstallmentPaid(let amount, let remaining):
            bannerMessage = "\(amount.liraText) kredi taksiti ödendi. Kalan borç \(remaining.liraText)."
        case .loanClosed:
            bannerMessage = "Araç yatırım kredisi tamamen kapandı."
        case .shopUpgraded(let level):
            bannerMessage = "Dükkân \(level). seviyeye yükseldi."
        case .washBayUpgraded(let level):
            bannerMessage = "Yıkama bölümü Seviye \(level) oldu. Daha hızlı ve etkili temiz teslim açıldı."
        default:
            break
        }
    }
}
