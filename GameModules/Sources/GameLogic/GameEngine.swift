import Foundation
import GameDomain

public struct GameEngine: Sendable {
    public private(set) var state: GameState
    public let catalog: ContentCatalog

    public init(state: GameState, catalog: ContentCatalog) {
        self.state = state
        self.catalog = catalog
    }

    public init(catalog: ContentCatalog, seed: UInt64 = 0x0A70_7A11) {
        self.init(
            state: GameState(
                startingCash: catalog.balance.startingCash,
                daySlots: catalog.balance.daySlots,
                randomSeed: seed
            ),
            catalog: catalog
        )
    }

    @discardableResult
    public mutating func handle(_ command: GameCommand) throws -> [GameEvent] {
        let events: [GameEvent]
        switch command {
        case .prepareWorld:
            events = prepareWorld()
        case .advanceTime(let minutes):
            guard minutes > 0 else { throw GameRuleError.invalidCommand("Zaman sıfırdan büyük ilerlemeli.") }
            events = advanceClock(by: minutes)
        case .acceptOffer(let id):
            events = try acceptOffer(id)
        case .declineOffer(let id):
            events = try declineOffer(id)
        case .performInspection(let jobID, let kind):
            events = try performInspection(jobID: jobID, kind: kind)
        case .diagnose(let jobID, let faultID):
            events = try diagnose(jobID: jobID, faultID: faultID)
        case .buyPart(let jobID, let quality):
            events = try buyPart(jobID: jobID, quality: quality)
        case .completeRepair(let jobID, let performance):
            events = try completeRepair(jobID: jobID, performance: performance)
        case .completeMaintenanceTask(let jobID, let task, let performance):
            events = try completeMaintenanceTask(jobID: jobID, task: task, performance: performance)
        case .setPrice(let jobID, let strategy, let hidePartQuality):
            events = try setPrice(jobID: jobID, strategy: strategy, hidePartQuality: hidePartQuality)
        case .washVehicle(let jobID):
            events = try washVehicle(jobID: jobID)
        case .hireApprentice:
            events = try hireApprentice()
        case .assignApprentice(let apprenticeID, let jobID, let task):
            events = try assignApprentice(apprenticeID: apprenticeID, jobID: jobID, task: task)
        case .upgradeShop:
            events = try upgradeShop()
        case .purchaseAuctionLot(let lotID):
            events = try purchaseAuctionLot(lotID)
        case .completeProjectRepair(let projectID, let task, let performance):
            events = try completeProjectRepair(projectID: projectID, task: task, performance: performance)
        case .listProjectCar(let projectID, let askingPrice, let discloseDamage):
            events = try listProjectCar(projectID: projectID, askingPrice: askingPrice, discloseDamage: discloseDamage)
        case .cancelProjectListing(let projectID):
            events = try cancelProjectListing(projectID: projectID)
        case .checkVehicleListings:
            events = advanceClock(by: 180)
        case .takeLoan(let amount, let plan):
            events = try takeLoan(amount: amount, plan: plan)
        case .grantPurchase(let transactionID, let cash, let themeID):
            events = grantPurchase(transactionID: transactionID, cash: cash, themeID: themeID)
        }

        state.parentRevision = state.revision
        state.revision += 1
        state.modifiedAt = Date()
        return events
    }

    private mutating func prepareWorld() -> [GameEvent] {
        var events: [GameEvent] = []
        var createdInitialOffer = false
        if state.offers.isEmpty, state.activeJobs.isEmpty, let offer = makeCustomerOffer() {
            state.offers.append(offer)
            createdInitialOffer = true
            events.append(.customerArrived(offer.id))
            if state.revision == 0 {
                events.append(.tutorial("Ustan: Müşteriyi dinle, sonra aracı kendin kontrol et. Söylenenle çıkan her zaman aynı olmaz."))
            }
        }
        if state.auction == nil {
            state.auction = makeAuction()
            events.append(.auctionOpened)
        }
        if createdInitialOffer { scheduleNextCustomer() }
        return events
    }

    private mutating func advanceClock(by minutes: Int) -> [GameEvent] {
        let previousDay = state.day
        state.totalMinutes += minutes
        state.day = state.totalMinutes / 1_440 + 1
        var events: [GameEvent] = [.timeAdvanced(state.totalMinutes)]

        if state.day > previousDay {
            for newDay in (previousDay + 1)...state.day {
                events.append(contentsOf: processNewDay(newDay))
            }
        }

        let expired = state.offers.filter { $0.expiresAtMinute <= state.totalMinutes }
        if !expired.isEmpty {
            state.offers.removeAll { $0.expiresAtMinute <= state.totalMinutes }
            events.append(contentsOf: expired.map { .customerLeft($0.id) })
        }

        while state.totalMinutes >= state.nextCustomerArrivalMinute {
            if isBusinessHour, state.offers.count < 3, let offer = makeCustomerOffer() {
                state.offers.append(offer)
                events.append(.customerArrived(offer.id))
            }
            scheduleNextCustomer()
            if !isBusinessHour {
                state.nextCustomerArrivalMinute = nextOpeningMinute(after: state.totalMinutes)
                break
            }
        }
        events.append(contentsOf: processLoanPayments())
        events.append(contentsOf: processVehicleListings())
        return events
    }

    private mutating func acceptOffer(_ id: UUID) throws -> [GameEvent] {
        guard let index = state.offers.firstIndex(where: { $0.id == id }) else {
            throw GameRuleError.invalidCommand("Bu müşteri artık dükkânda beklemiyor.")
        }
        let capacity = catalog.shopLevel(state.shopLevel)?.capacity ?? 1
        guard state.activeJobs.count + state.projectCars.count < capacity else {
            throw GameRuleError.shopIsFull
        }
        let offer = state.offers.remove(at: index)
        state.activeJobs.append(RepairJob(offer: offer))
        return [.offerAccepted(id)]
    }

    private mutating func declineOffer(_ id: UUID) throws -> [GameEvent] {
        guard state.offers.contains(where: { $0.id == id }) else {
            throw GameRuleError.invalidCommand("Müşteri bulunamadı.")
        }
        state.offers.removeAll { $0.id == id }
        var events = advanceClock(by: 15)
        events.append(.customerLeft(id))
        return events
    }

    private mutating func performInspection(jobID: UUID, kind: InspectionKind) throws -> [GameEvent] {
        guard let index = state.activeJobs.firstIndex(where: { $0.id == jobID }),
              state.activeJobs[index].serviceKind == .faultRepair,
              state.activeJobs[index].stage == .awaitingInspection || state.activeJobs[index].stage == .awaitingDiagnosis,
              !state.activeJobs[index].performedInspections.contains(kind),
              let actualID = state.activeJobs[index].actualFaultID,
              let actualFault = catalog.fault(id: actualID) else {
            throw GameRuleError.invalidCommand("Bu kontrol şu anda yapılamaz.")
        }

        let finding = actualFault.inspectionFindings[kind]
            ?? fallbackFinding(for: actualFault, inspection: kind)
        state.activeJobs[index].performedInspections.append(kind)
        state.activeJobs[index].findings.append(finding)

        let related = state.activeJobs[index].suspectedFaultIDs.filter { id in
            guard let fault = catalog.fault(id: id) else { return false }
            return fault.inspectionFindings[kind] != nil || inferredInspections(for: fault.area).contains(kind)
        }
        state.activeJobs[index].candidateFaultIDs = Array(Set(state.activeJobs[index].candidateFaultIDs + related)).sorted()
        if state.activeJobs[index].performedInspections.count >= 2 {
            state.activeJobs[index].stage = .awaitingDiagnosis
        }
        let duration = supports(.diagnosticLab) ? max(5, kind.durationMinutes * 80 / 100) : kind.durationMinutes
        var events = advanceClock(by: duration)
        events.append(.inspectionCompleted(kind: kind, finding: finding))
        return events
    }

    private mutating func diagnose(jobID: UUID, faultID: String) throws -> [GameEvent] {
        guard let index = state.activeJobs.firstIndex(where: { $0.id == jobID }),
              state.activeJobs[index].serviceKind == .faultRepair,
              state.activeJobs[index].stage == .awaitingDiagnosis,
              state.activeJobs[index].candidateFaultIDs.contains(faultID),
              catalog.fault(id: faultID) != nil else {
            throw GameRuleError.invalidCommand("Önce yeterli kontrol yapıp bağlantılı bir teşhis seçmelisin.")
        }

        let correct = state.activeJobs[index].actualFaultID == faultID
        state.activeJobs[index].diagnosedFaultID = correct ? faultID : nil
        if correct {
            state.activeJobs[index].stage = .awaitingPart
        } else {
            state.reputation.craftsmanship -= 1
            state.reputation.clamp()
        }
        var events = advanceClock(by: 20)
        events.append(.diagnosisCompleted(correct: correct))
        events.append(.reputationChanged(state.reputation))
        return events
    }

    private mutating func buyPart(jobID: UUID, quality: PartQuality) throws -> [GameEvent] {
        guard let index = state.activeJobs.firstIndex(where: { $0.id == jobID }),
              state.activeJobs[index].stage == .awaitingPart else {
            throw GameRuleError.invalidCommand("Bu iş için henüz parça seçilemez.")
        }

        let job = state.activeJobs[index]
        let partName: String
        let faultID: String
        let baseCost: Money
        if job.serviceKind == .periodicMaintenance {
            partName = "yıllık bakım seti"
            faultID = "periodic_maintenance"
            baseCost = Money(minorUnits: 420_000)
        } else if let diagnosedID = job.diagnosedFaultID, let fault = catalog.fault(id: diagnosedID) {
            partName = fault.partName
            faultID = diagnosedID
            baseCost = fault.basePartCost
        } else {
            throw GameRuleError.invalidCommand("Önce doğru teşhisi koymalısın.")
        }

        var cost = percent(baseCost, quality.costPercent)
        if supports(.partsStorage) { cost = percent(cost, 90) }
        let creditLimit = Money(minorUnits: -1_000_000)
        guard state.cash - cost >= creditLimit else { throw GameRuleError.notEnoughMoney }
        state.cash = state.cash - cost
        state.activeJobs[index].partQuality = quality
        state.activeJobs[index].stage = .readyForRepair
        state.inventory.append(InventoryItem(
            id: state.activeJobs[index].id,
            jobID: jobID,
            faultID: faultID,
            partName: partName,
            quality: quality,
            purchasePrice: cost
        ))
        recordFinance(
            amount: Money(minorUnits: -cost.minorUnits),
            category: .parts,
            note: "\(quality.title) \(partName)"
        )
        var events = advanceClock(by: 30)
        events.append(.moneyChanged(Money(minorUnits: -cost.minorUnits), reason: "\(quality.title) \(partName)"))
        return events
    }

    private mutating func completeRepair(jobID: UUID, performance: Int) throws -> [GameEvent] {
        guard let index = state.activeJobs.firstIndex(where: { $0.id == jobID }),
              state.activeJobs[index].serviceKind == .faultRepair,
              state.activeJobs[index].stage == .readyForRepair,
              let partQuality = state.activeJobs[index].partQuality,
              let actualID = state.activeJobs[index].actualFaultID,
              let actualFault = catalog.fault(id: actualID) else {
            throw GameRuleError.invalidCommand("Araç tamire hazır değil.")
        }

        var random = SeededRandomSource(seed: state.randomSeed)
        let skill = state.expertise[actualFault.area, default: SkillProgress()].level
        let equipment = catalog.shopLevel(state.shopLevel)?.equipmentBonus ?? 0
        let jitter = random.next(upperBound: 11) - 5
        let score = max(0, min(100, performance + skill * 3 + equipment + (partQuality.reliabilityScore - 70) / 3 + jitter))
        state.randomSeed = random.state
        let quality = workmanship(for: score)
        state.activeJobs[index].workmanship = quality
        state.activeJobs[index].repairPerformanceTotal = performance
        state.activeJobs[index].repairPerformanceCount = 1
        state.activeJobs[index].stage = .awaitingPrice
        let xp = max(15, actualFault.requiredSkill * 14 + performance / 8)
        let experienceEvent: GameEvent?
        let apprenticeEvent: GameEvent?
        if let apprenticeID = state.activeJobs[index].repairedByApprenticeID,
           let apprenticeIndex = state.apprentices.firstIndex(where: { $0.id == apprenticeID }) {
            state.apprentices[apprenticeIndex].addExperience(xp)
            experienceEvent = nil
            apprenticeEvent = .apprenticeCompleted(
                name: state.apprentices[apprenticeIndex].name,
                quality: quality
            )
        } else {
            experienceEvent = grantExperience(area: actualFault.area, amount: xp)
            apprenticeEvent = nil
        }
        var events = advanceClock(by: 90 + actualFault.requiredSkill * 15)
        events.append(.repairCompleted(quality))
        if let experienceEvent { events.append(experienceEvent) }
        if let apprenticeEvent { events.append(apprenticeEvent) }
        return events
    }

    private mutating func completeMaintenanceTask(
        jobID: UUID,
        task: MaintenanceTask,
        performance: Int
    ) throws -> [GameEvent] {
        guard let index = state.activeJobs.firstIndex(where: { $0.id == jobID }),
              state.activeJobs[index].serviceKind == .periodicMaintenance,
              state.activeJobs[index].stage == .readyForRepair,
              state.activeJobs[index].maintenanceTasks.contains(task),
              !state.activeJobs[index].completedMaintenanceTasks.contains(task) else {
            throw GameRuleError.invalidCommand("Bu bakım adımı şu anda yapılamaz.")
        }

        state.activeJobs[index].completedMaintenanceTasks.append(task)
        state.activeJobs[index].repairPerformanceTotal += performance
        state.activeJobs[index].repairPerformanceCount += 1
        let xp = 18 + performance / 10
        var events = advanceClock(by: 25)
        events.append(.maintenanceTaskCompleted(task))
        if let apprenticeID = state.activeJobs[index].repairedByApprenticeID,
           let apprenticeIndex = state.apprentices.firstIndex(where: { $0.id == apprenticeID }) {
            state.apprentices[apprenticeIndex].addExperience(xp)
            events.append(.apprenticeCompleted(
                name: state.apprentices[apprenticeIndex].name,
                quality: workmanship(for: performance)
            ))
        } else {
            events.append(grantExperience(area: task.skillArea, amount: xp))
        }

        if state.activeJobs[index].completedMaintenanceTasks.count == state.activeJobs[index].maintenanceTasks.count {
            let average = state.activeJobs[index].repairPerformanceTotal / max(1, state.activeJobs[index].repairPerformanceCount)
            state.activeJobs[index].workmanship = workmanship(for: average + 8)
            state.activeJobs[index].stage = .awaitingPrice
            events.append(.repairCompleted(state.activeJobs[index].workmanship ?? .acceptable))
        }
        return events
    }

    private mutating func setPrice(
        jobID: UUID,
        strategy: PriceStrategy,
        hidePartQuality: Bool
    ) throws -> [GameEvent] {
        guard let index = state.activeJobs.firstIndex(where: { $0.id == jobID }),
              state.activeJobs[index].stage == .awaitingPrice,
              let partQuality = state.activeJobs[index].partQuality,
              let workmanship = state.activeJobs[index].workmanship,
              let inventory = state.inventory.first(where: { $0.jobID == jobID }),
              let customer = catalog.customer(id: state.activeJobs[index].customerID) else {
            throw GameRuleError.invalidCommand("İş tamamlanmadan fiyat belirlenemez.")
        }

        var random = SeededRandomSource(seed: state.randomSeed)
        let job = state.activeJobs[index]
        let labor = laborValue(for: job)
        let normalTotal = inventory.purchasePrice + labor
        let requested = percent(normalTotal, strategy.multiplierPercent)
        let riskBonus = strategy == .excessive ? 45 : (strategy == .high ? 16 : 0)
        let noticed = strategy != .affordable && strategy != .fair
            && random.next(upperBound: 100) < min(92, customer.priceSensitivity * 6 + riskBonus)
        let paid = noticed ? normalTotal : requested
        let reaction: String
        if noticed {
            let lines = [
                "\(customer.name) hesabı görünce kaşını kaldırdı; fiyat pazarlıkla normale indi.",
                "‘Usta bu paraya kaputu da mı veriyorsun?’ pazarlığı başladı; normal ücrette anlaşıldı.",
                "Müşteri telefondan parça fiyatına baktı. Uçuk kısım masada kaldı."
            ]
            reaction = lines[random.next(upperBound: lines.count)]
        } else if strategy == .excessive {
            let lines = [
                "Müşteri aceleden ödedi; çayı soğuyunca hesabı yeniden düşünebilir.",
                "Fiyat kabul edildi ama \(customer.name) faturayı cebine dikkatlice koydu.",
                "Para alındı. Sanayi grubuna ‘sizce normal mi?’ mesajı gitme ihtimali yüksek."
            ]
            reaction = lines[random.next(upperBound: lines.count)]
        } else if strategy == .affordable {
            let lines = [
                "Müşteri ‘Allah bereket versin usta’ deyip anahtarı gülerek aldı.",
                "Fiyat yüz güldürdü; dükkânın adı bir sonraki çay sohbetine yazıldı.",
                "\(customer.name) beklediğinden az ödeyince bir sonraki bakıma söz verdi."
            ]
            reaction = lines[random.next(upperBound: lines.count)]
        } else {
            let lines = [
                "Müşteri motoru dinledi, başını salladı ve aracı teslim aldı.",
                "Anahtar teslim edildi; ‘ses yoksa mesele yok’ denip yola çıkıldı.",
                "\(customer.name) yapılanları dinledi, hesabı ödedi ve dükkândan ayrıldı."
            ]
            reaction = lines[random.next(upperBound: lines.count)]
        }

        state.cash = state.cash + paid
        recordFinance(amount: paid, category: .customerIncome, note: "\(customer.name) araç teslimi")
        state.activeJobs[index].strategy = strategy
        state.activeJobs[index].hidePartQuality = hidePartQuality
        state.activeJobs[index].quote = paid
        applyReputation(for: workmanship, strategy: strategy, concealed: hidePartQuality, noticed: noticed)
        if job.isWashed {
            state.reputation.trust += 1
            state.reputation.clamp()
        }
        let newReview = makeReview(
            for: job,
            workmanship: workmanship,
            strategy: strategy,
            noticed: noticed,
            random: &random
        )
        if let newReview { addReview(newReview) }
        scheduleConsequences(
            for: job,
            paid: paid,
            quality: workmanship,
            partQuality: partQuality,
            strategy: strategy,
            concealed: hidePartQuality,
            noticed: noticed,
            random: &random
        )
        state.randomSeed = random.state
        state.inventory.removeAll { $0.jobID == jobID }
        state.activeJobs.remove(at: index)

        var events: [GameEvent] = [
            .moneyChanged(paid, reason: "Müşteri ödemesi"),
            .priceSettled(paid, reaction: reaction),
            .reputationChanged(state.reputation)
        ]
        if let newReview { events.append(.reviewReceived(newReview)) }
        return events
    }

    private mutating func washVehicle(jobID: UUID) throws -> [GameEvent] {
        guard supports(.washBay) else {
            throw GameRuleError.invalidCommand("Araç yıkamak için dükkânı büyütüp yıkama alanını açmalısın.")
        }
        guard let index = state.activeJobs.firstIndex(where: { $0.id == jobID }),
              state.activeJobs[index].stage == .awaitingPrice,
              !state.activeJobs[index].isWashed else {
            throw GameRuleError.invalidCommand("Bu araç şu anda yıkanamaz.")
        }
        let cost = catalog.balance.washCost
        guard state.cash >= cost else { throw GameRuleError.notEnoughMoney }
        state.cash = state.cash - cost
        state.activeJobs[index].isWashed = true
        recordFinance(amount: Money(minorUnits: -cost.minorUnits), category: .wash, note: "Teslim öncesi araç yıkama")
        var events = advanceClock(by: 30)
        events.append(.vehicleWashed(jobID))
        events.append(.moneyChanged(Money(minorUnits: -cost.minorUnits), reason: "Araç yıkama"))
        return events
    }

    private mutating func hireApprentice() throws -> [GameEvent] {
        guard let shop = catalog.shopLevel(state.shopLevel), shop.facilities.contains(.apprenticeStation) else {
            throw GameRuleError.invalidCommand("Çırak almak için çalışma tezgâhı olan daha büyük dükkân gerekli.")
        }
        guard state.apprentices.count < shop.maxApprentices else {
            throw GameRuleError.invalidCommand("Bu dükkânda başka çırak için çalışma alanı yok.")
        }
        let cost = catalog.balance.apprenticeHireCost
        guard state.cash >= cost else { throw GameRuleError.notEnoughMoney }
        var random = SeededRandomSource(seed: state.randomSeed)
        let names = ["Mert", "Efe", "Can", "Burak", "Deniz", "Ayaz"]
        let usedNames = Set(state.apprentices.map(\.name))
        let availableNames = names.filter { !usedNames.contains($0) }
        let name = availableNames.isEmpty ? "Çırak \(state.apprentices.count + 1)" : availableNames[random.next(upperBound: availableNames.count)]
        let apprentice = Apprentice(id: random.nextUUID(), name: name)
        state.randomSeed = random.state
        state.cash = state.cash - cost
        state.apprentices.append(apprentice)
        recordFinance(amount: Money(minorUnits: -cost.minorUnits), category: .wages, note: "\(name) işe giriş ve ekipman")
        return [
            .moneyChanged(Money(minorUnits: -cost.minorUnits), reason: "Çırak işe alımı"),
            .apprenticeHired(apprentice)
        ]
    }

    private mutating func assignApprentice(
        apprenticeID: UUID,
        jobID: UUID,
        task: MaintenanceTask?
    ) throws -> [GameEvent] {
        guard let apprentice = state.apprentices.first(where: { $0.id == apprenticeID }),
              let jobIndex = state.activeJobs.firstIndex(where: { $0.id == jobID }),
              state.activeJobs[jobIndex].stage == .readyForRepair else {
            throw GameRuleError.invalidCommand("Çırak bu işe atanamıyor.")
        }
        var random = SeededRandomSource(seed: state.randomSeed)
        let performance = min(92, 46 + apprentice.level * 9 + random.next(upperBound: 19))
        state.randomSeed = random.state
        state.activeJobs[jobIndex].repairedByApprenticeID = apprenticeID
        let events: [GameEvent]
        if state.activeJobs[jobIndex].serviceKind == .periodicMaintenance {
            guard let task else {
                throw GameRuleError.invalidCommand("Çırağa verilecek bakım adımını seçmelisin.")
            }
            events = try completeMaintenanceTask(jobID: jobID, task: task, performance: performance)
        } else {
            guard task == nil else { throw GameRuleError.invalidCommand("Bu tamirde bakım adımı bulunmuyor.") }
            events = try completeRepair(jobID: jobID, performance: performance)
        }
        if let remainingIndex = state.activeJobs.firstIndex(where: { $0.id == jobID }) {
            state.activeJobs[remainingIndex].repairedByApprenticeID = nil
        }
        return events
    }

    private mutating func processNewDay(_ newDay: Int) -> [GameEvent] {
        let fixedCosts: [(Money, FinanceCategory, String)] = [
            (catalog.balance.dailyRent, .rent, "Günlük kira payı"),
            (catalog.balance.dailyUtilities, .utilities, "Elektrik, su ve lift enerjisi"),
            (catalog.balance.dailySupplies, .supplies, "Sarf ve temizlik malzemeleri")
        ]
        var events: [GameEvent] = []
        for (cost, category, note) in fixedCosts {
            state.cash = state.cash - cost
            recordFinance(amount: Money(minorUnits: -cost.minorUnits), category: category, note: note)
            events.append(.moneyChanged(Money(minorUnits: -cost.minorUnits), reason: category.title))
        }
        if !state.apprentices.isEmpty {
            let wage = catalog.balance.apprenticeDailyWage * state.apprentices.count
            state.cash = state.cash - wage
            recordFinance(amount: Money(minorUnits: -wage.minorUnits), category: .wages, note: "\(state.apprentices.count) çırak günlük ücreti")
            events.append(.moneyChanged(Money(minorUnits: -wage.minorUnits), reason: "Çırak ücretleri"))
        }
        if state.cash < Money(minorUnits: -500_000) {
            let support = Money(minorUnits: -200_000 - state.cash.minorUnits)
            state.cash = state.cash + support
            recordFinance(amount: support, category: .support, note: "Parçacı veresiye desteği")
            events.append(.consequence("Parçacı veresiye defterini açtı: ‘İşi çevir usta, sonra konuşuruz.’"))
        }

        let due = state.consequences.filter { $0.dueDay <= newDay }
        state.consequences.removeAll { $0.dueDay <= newDay }
        for consequence in due {
            switch consequence.kind {
            case .complaint, .comeback:
                state.cash = state.cash - consequence.amount
                recordFinance(amount: Money(minorUnits: -consequence.amount.minorUnits), category: .fine, note: consequence.message)
                state.reputation.trust -= 4
                state.reputation.craftsmanship -= 2
            case .inspection:
                state.cash = state.cash - consequence.amount
                recordFinance(amount: Money(minorUnits: -consequence.amount.minorUnits), category: .fine, note: consequence.message)
                state.reputation.suspicion -= 8
                state.reputation.trust -= 3
            case .referral:
                state.reputation.trust += 3
                state.cash = state.cash + consequence.amount
                recordFinance(amount: consequence.amount, category: .customerIncome, note: consequence.message)
            }
            state.reputation.clamp()
            events.append(.consequence(consequence.message))
        }

        if newDay >= 4, (newDay - 4).isMultiple(of: 3), state.auction == nil {
            state.auction = makeAuction()
            events.append(.auctionOpened)
        }
        return events
    }

    private mutating func upgradeShop() throws -> [GameEvent] {
        let nextLevel = state.shopLevel + 1
        guard let definition = catalog.shopLevel(nextLevel) else {
            throw GameRuleError.invalidCommand("Dükkân zaten en yüksek seviyede.")
        }
        guard state.cash >= definition.upgradeCost else { throw GameRuleError.notEnoughMoney }
        state.cash = state.cash - definition.upgradeCost
        recordFinance(
            amount: Money(minorUnits: -definition.upgradeCost.minorUnits),
            category: .shopUpgrade,
            note: definition.name
        )
        state.shopLevel = nextLevel
        return [
            .moneyChanged(Money(minorUnits: -definition.upgradeCost.minorUnits), reason: "Dükkân yükseltmesi"),
            .shopUpgraded(nextLevel)
        ]
    }

    private mutating func purchaseAuctionLot(_ lotID: UUID) throws -> [GameEvent] {
        guard var auction = state.auction,
              let lotIndex = auction.lots.firstIndex(where: { $0.id == lotID }) else {
            throw GameRuleError.invalidCommand("Bu hasarlı araç artık satışta değil.")
        }
        let lot = auction.lots[lotIndex]
        guard state.cash >= lot.fixedPrice else { throw GameRuleError.notEnoughMoney }
        let capacity = catalog.shopLevel(state.shopLevel)?.capacity ?? 1
        guard state.activeJobs.count + state.projectCars.count < capacity else {
            throw GameRuleError.shopIsFull
        }
        state.cash = state.cash - lot.fixedPrice
        state.projectCars.append(ProjectCar(
            id: lot.id,
            vehicleID: lot.vehicleID,
            faultIDs: lot.mechanicalFaultIDs,
            purchasePrice: lot.fixedPrice,
            purchasedAtMinute: state.totalMinutes,
            panelDamages: lot.panelDamages,
            airbagsDeployed: lot.airbagsDeployed,
            startsAndDrives: lot.startsAndDrives,
            recordedDamage: lot.recordedDamage
        ))
        recordFinance(
            amount: Money(minorUnits: -lot.fixedPrice.minorUnits),
            category: .salvageVehicle,
            note: catalog.vehicle(id: lot.vehicleID)?.name ?? "Hasarlı araç"
        )
        auction.lots.remove(at: lotIndex)
        state.auction = auction.lots.isEmpty ? nil : auction
        let name = catalog.vehicle(id: lot.vehicleID)?.name ?? "Hasarlı araç"
        return [
            .auctionWon(vehicleName: name, price: lot.fixedPrice),
            .moneyChanged(Money(minorUnits: -lot.fixedPrice.minorUnits), reason: "Hasarlı araç alımı")
        ]
    }

    private mutating func completeProjectRepair(
        projectID: UUID,
        task: ProjectRepairTask,
        performance: Int
    ) throws -> [GameEvent] {
        guard let index = state.projectCars.firstIndex(where: { $0.id == projectID }),
              state.projectCars[index].stage == .awaitingRepair else {
            throw GameRuleError.invalidCommand("Bu proje araç tamir beklemiyor.")
        }
        let project = state.projectCars[index]
        guard let vehicle = catalog.vehicle(id: project.vehicleID) else {
            throw GameRuleError.contentMissing(project.vehicleID)
        }
        let requiredTasks = projectRepairTasks(for: project)
        guard requiredTasks.contains(task), !project.completedRepairTasks.contains(task) else {
            throw GameRuleError.invalidCommand("Bu restorasyon işi tamamlanmış veya araca ait değil.")
        }
        let taskCost = VehicleTradingRules.repairTaskCost(
            task: task,
            project: project,
            vehicle: vehicle,
            catalog: catalog,
            hasBodyPaintBooth: supports(.bodyPaintBooth)
        )
        guard state.cash >= taskCost else { throw GameRuleError.notEnoughMoney }
        state.cash = state.cash - taskCost
        recordFinance(
            amount: Money(minorUnits: -taskCost.minorUnits),
            category: .restoration,
            note: projectRepairTitle(task)
        )
        let skillArea: SkillArea = switch task {
        case .mechanical(let faultID): catalog.fault(id: faultID)?.area ?? .engine
        case .panel: .body
        case .airbag: .electrical
        }
        let skill = state.expertise[skillArea, default: SkillProgress()].level
        let score = min(100, max(20, performance + skill * 2))
        state.projectCars[index].completedRepairTasks.insert(task)
        state.projectCars[index].restorationScoreTotal += score
        state.projectCars[index].restorationCost = state.projectCars[index].restorationCost + taskCost
        let allDone = state.projectCars[index].completedRepairTasks.count == requiredTasks.count
        if allDone {
            state.projectCars[index].restorationQuality = state.projectCars[index].restorationScoreTotal / max(1, requiredTasks.count)
            state.projectCars[index].startsAndDrives = true
            state.projectCars[index].stage = .readyForSale
        }
        let duration = taskDuration(task)
        var events = advanceClock(by: duration)
        events.append(.moneyChanged(Money(minorUnits: -taskCost.minorUnits), reason: projectRepairTitle(task)))
        events.append(.projectRepairCompleted(projectID: projectID, task: task))
        if allDone { events.append(.projectCarReady(projectID)) }
        return events
    }

    private func projectRepairTasks(for project: ProjectCar) -> [ProjectRepairTask] {
        project.faultIDs.map { .mechanical(faultID: $0) }
            + project.panelDamages.filter { $0.condition != .original }.map { .panel($0.panel) }
            + (project.airbagsDeployed ? [.airbag] : [])
    }

    private func projectRepairTitle(_ task: ProjectRepairTask) -> String {
        switch task {
        case .mechanical(let faultID): catalog.fault(id: faultID)?.partName ?? "Mekanik onarım"
        case .panel(let panel): "\(panel.title) kaporta onarımı"
        case .airbag: "Hava yastığı sistemi"
        }
    }

    private func taskDuration(_ task: ProjectRepairTask) -> Int {
        switch task {
        case .mechanical: 60
        case .panel: 75
        case .airbag: 60
        }
    }

    private mutating func listProjectCar(
        projectID: UUID,
        askingPrice: Money,
        discloseDamage: Bool
    ) throws -> [GameEvent] {
        guard let index = state.projectCars.firstIndex(where: { $0.id == projectID }),
              state.projectCars[index].stage == .readyForSale,
              let vehicle = catalog.vehicle(id: state.projectCars[index].vehicleID) else {
            throw GameRuleError.invalidCommand("Bu araç henüz satışa hazır değil.")
        }
        guard askingPrice > .zero else {
            throw GameRuleError.invalidCommand("İlan fiyatı sıfırdan büyük olmalı.")
        }
        guard state.cash >= VehicleTradingRules.listingFee else { throw GameRuleError.notEnoughMoney }
        let estimate = VehicleTradingRules.listingEstimate(
            project: state.projectCars[index],
            vehicle: vehicle,
            askingPrice: askingPrice,
            ratingTenths: state.ratingTenths,
            hasShowroom: supports(.vehicleShowroom),
            discloseDamage: discloseDamage
        )
        state.cash = state.cash - VehicleTradingRules.listingFee
        recordFinance(
            amount: Money(minorUnits: -VehicleTradingRules.listingFee.minorUnits),
            category: .listingFee,
            note: "\(vehicle.name) ilan yayını"
        )
        state.projectCars[index].stage = .listed
        state.projectCars[index].askingPrice = askingPrice
        state.projectCars[index].disclosedDamage = discloseDamage
        state.projectCars[index].listedAtMinute = state.totalMinutes
        state.projectCars[index].nextBuyerCheckMinute = state.totalMinutes + 180
        return [
            .moneyChanged(Money(minorUnits: -VehicleTradingRules.listingFee.minorUnits), reason: "Araç ilanı"),
            .projectCarListed(price: askingPrice, saleChance: estimate.saleChancePercent)
        ]
    }

    private mutating func cancelProjectListing(projectID: UUID) throws -> [GameEvent] {
        guard let index = state.projectCars.firstIndex(where: { $0.id == projectID }),
              state.projectCars[index].stage == .listed else {
            throw GameRuleError.invalidCommand("Bu araç yayında bir ilana sahip değil.")
        }
        state.projectCars[index].stage = .readyForSale
        state.projectCars[index].askingPrice = nil
        state.projectCars[index].listedAtMinute = nil
        state.projectCars[index].nextBuyerCheckMinute = nil
        return [.projectListingExpired(projectID)]
    }

    private mutating func takeLoan(amount: Money, plan: LoanPlan) throws -> [GameEvent] {
        guard amount >= Money(minorUnits: 1_000_000) else {
            throw GameRuleError.invalidCommand("En düşük kredi tutarı 10.000 ₺ olmalı.")
        }
        guard amount <= BankingRules.availableCredit(for: state) else {
            throw GameRuleError.invalidCommand("Bu tutar bankanın kullanılabilir limitini aşıyor.")
        }
        let total = BankingRules.totalRepayment(for: amount, plan: plan)
        let installment = BankingRules.installmentAmount(for: amount, plan: plan)
        var random = SeededRandomSource(seed: state.randomSeed)
        let loan = BankLoan(
            id: random.nextUUID(),
            plan: plan,
            borrowedAmount: amount,
            totalRepayment: total,
            installmentAmount: installment,
            nextPaymentMinute: state.totalMinutes + plan.installmentIntervalDays * 1_440
        )
        state.randomSeed = random.state
        state.loans.append(loan)
        state.cash = state.cash + amount
        recordFinance(amount: amount, category: .loanProceeds, note: "\(plan.title) araç yatırım kredisi")
        return [.moneyChanged(amount, reason: "Banka kredisi"), .loanTaken(amount: amount, totalRepayment: total)]
    }

    private mutating func processLoanPayments() -> [GameEvent] {
        var events: [GameEvent] = []
        var index = 0
        while index < state.loans.count {
            while state.loans[index].nextPaymentMinute <= state.totalMinutes,
                  state.loans[index].remainingBalance > .zero {
                let payment = min(state.loans[index].installmentAmount, state.loans[index].remainingBalance)
                state.cash = state.cash - payment
                state.loans[index].remainingBalance = state.loans[index].remainingBalance - payment
                state.loans[index].remainingInstallments = max(0, state.loans[index].remainingInstallments - 1)
                state.loans[index].nextPaymentMinute += state.loans[index].installmentIntervalMinutes
                recordFinance(
                    amount: Money(minorUnits: -payment.minorUnits),
                    category: .loanPayment,
                    note: "\(state.loans[index].plan.title) kredi taksiti"
                )
                events.append(.moneyChanged(Money(minorUnits: -payment.minorUnits), reason: "Kredi taksiti"))
                events.append(.loanInstallmentPaid(
                    amount: payment,
                    remainingBalance: state.loans[index].remainingBalance
                ))
            }
            if state.loans[index].remainingBalance <= .zero {
                let id = state.loans[index].id
                state.loans.remove(at: index)
                events.append(.loanClosed(id))
            } else {
                index += 1
            }
        }
        return events
    }

    private mutating func processVehicleListings() -> [GameEvent] {
        var events: [GameEvent] = []
        var random = SeededRandomSource(seed: state.randomSeed)
        var index = 0
        while index < state.projectCars.count {
            guard state.projectCars[index].stage == .listed,
                  let askingPrice = state.projectCars[index].askingPrice,
                  let vehicle = catalog.vehicle(id: state.projectCars[index].vehicleID),
                  var nextCheck = state.projectCars[index].nextBuyerCheckMinute,
                  nextCheck <= state.totalMinutes else {
                index += 1
                continue
            }

            var sold = false
            while nextCheck <= state.totalMinutes, !sold {
                let estimate = VehicleTradingRules.listingEstimate(
                    project: state.projectCars[index],
                    vehicle: vehicle,
                    askingPrice: askingPrice,
                    ratingTenths: state.ratingTenths,
                    hasShowroom: supports(.vehicleShowroom),
                    discloseDamage: state.projectCars[index].disclosedDamage
                )
                sold = random.next(upperBound: 100) < estimate.saleChancePercent
                nextCheck += 360
            }

            if sold {
                let project = state.projectCars[index]
                state.cash = state.cash + askingPrice
                recordFinance(amount: askingPrice, category: .vehicleSale, note: vehicle.name)
                if project.disclosedDamage {
                    state.reputation.trust += 3
                } else {
                    state.reputation.suspicion += 8
                    if project.restorationQuality < 85 {
                        state.consequences.append(ScheduledConsequence(
                            id: random.nextUUID(),
                            dueDay: state.day + 2,
                            kind: .complaint,
                            amount: percent(askingPrice, 15),
                            message: "İlanda ağır hasar geçmişi saklanan aracın alıcısı ekspertiz raporuyla geri döndü; uzlaşma bedeli çıktı."
                        ))
                    }
                }
                state.reputation.clamp()
                state.projectCars.remove(at: index)
                events.append(.projectCarSold(price: askingPrice, honest: project.disclosedDamage))
                events.append(.reputationChanged(state.reputation))
            } else {
                state.projectCars[index].nextBuyerCheckMinute = nextCheck
                events.append(.projectListingExpired(state.projectCars[index].id))
                index += 1
            }
        }
        state.randomSeed = random.state
        return events
    }

    private mutating func grantPurchase(transactionID: String, cash: Money?, themeID: String?) -> [GameEvent] {
        guard !state.processedTransactionIDs.contains(transactionID) else { return [] }
        state.processedTransactionIDs.insert(transactionID)
        if let cash { state.cash = state.cash + cash }
        if let themeID { state.selectedThemeID = themeID }
        var events: [GameEvent] = [.purchaseGranted(transactionID)]
        if let cash { events.append(.moneyChanged(cash, reason: "Mağaza paketi")) }
        return events
    }

    private mutating func makeCustomerOffer() -> CustomerOffer? {
        let unlockedVehicleCount = min(catalog.vehicles.count, state.shopLevel == 1 ? 3 : (state.shopLevel == 2 ? 5 : catalog.vehicles.count))
        let vehicles = Array(catalog.vehicles.prefix(unlockedVehicleCount))
        guard !catalog.customers.isEmpty, !vehicles.isEmpty, !catalog.faults.isEmpty else { return nil }

        var random = SeededRandomSource(seed: state.randomSeed)
        let customer = catalog.customers[random.next(upperBound: catalog.customers.count)]
        let vehicle = vehicles[random.next(upperBound: vehicles.count)]
        let isMaintenance = supports(.periodicMaintenance) && random.next(upperBound: 100) < 24
        let waitingAreaBonus = supports(.waitingArea) ? 60 : 0
        let offer: CustomerOffer
        if isMaintenance {
            let count = 3 + random.next(upperBound: 3)
            let tasks = Array(MaintenanceTask.allCases.shuffledDeterministically(using: &random).prefix(count))
            offer = CustomerOffer(
                id: random.nextUUID(),
                customerID: customer.id,
                vehicleID: vehicle.id,
                serviceKind: .periodicMaintenance,
                actualFaultID: nil,
                suspectedFaultIDs: [],
                maintenanceTasks: tasks,
                complaint: "Yıllık bakım zamanı geldi. Yağına suyuna bakıp içimizi rahatlat usta.",
                arrivedAtMinute: state.totalMinutes,
                expiresAtMinute: state.totalMinutes + 75 + customer.patience * 15 + waitingAreaBonus
            )
        } else {
            let actual = catalog.faults[random.next(upperBound: catalog.faults.count)]
            let alternatives = catalog.faults
                .filter { $0.id != actual.id && ($0.area == actual.area || sharesInspection($0, actual)) }
                .shuffledDeterministically(using: &random)
            let candidateIDs = ([actual.id] + alternatives.prefix(3).map(\.id)).shuffledDeterministically(using: &random)
            offer = CustomerOffer(
                id: random.nextUUID(),
                customerID: customer.id,
                vehicleID: vehicle.id,
                actualFaultID: actual.id,
                suspectedFaultIDs: candidateIDs,
                complaint: ([actual.complaint] + actual.complaintVariants)[
                    random.next(upperBound: max(1, actual.complaintVariants.count + 1))
                ],
                arrivedAtMinute: state.totalMinutes,
                expiresAtMinute: state.totalMinutes + 75 + customer.patience * 15 + waitingAreaBonus
            )
        }
        state.randomSeed = random.state
        return offer
    }

    private mutating func scheduleNextCustomer() {
        var random = SeededRandomSource(seed: state.randomSeed)
        let ratingAdvantage = max(0, state.ratingTenths - 30) * 2
        let base = max(35, 105 - ratingAdvantage)
        state.nextCustomerArrivalMinute = max(state.totalMinutes + 5, state.nextCustomerArrivalMinute) + base + random.next(upperBound: 61)
        state.randomSeed = random.state
    }

    private var isBusinessHour: Bool {
        let minute = state.minuteOfDay
        return minute >= 8 * 60 && minute < 20 * 60
    }

    private func nextOpeningMinute(after minute: Int) -> Int {
        let dayStart = minute - minute % 1_440
        if minute % 1_440 < 8 * 60 { return dayStart + 8 * 60 }
        return dayStart + 1_440 + 8 * 60
    }

    private func inferredInspections(for area: SkillArea) -> Set<InspectionKind> {
        switch area {
        case .engine: [.visual, .startEngine, .listen, .fluids, .diagnosticScanner]
        case .electrical: [.startEngine, .diagnosticScanner, .visual]
        case .chassis: [.lift, .wheelPlay, .testDrive, .listen]
        case .body: [.visual, .lift]
        }
    }

    private func fallbackFinding(for fault: FaultDefinition, inspection: InspectionKind) -> String {
        let relevant = inferredInspections(for: fault.area).contains(inspection)
        if relevant, let clue = fault.clues.first { return clue }
        return "Bu kontrolde belirgin bir sorun görülmedi."
    }

    private func sharesInspection(_ lhs: FaultDefinition, _ rhs: FaultDefinition) -> Bool {
        let left = Set(lhs.inspectionFindings.keys).union(inferredInspections(for: lhs.area))
        let right = Set(rhs.inspectionFindings.keys).union(inferredInspections(for: rhs.area))
        return !left.isDisjoint(with: right)
    }

    private mutating func grantExperience(area: SkillArea, amount: Int) -> GameEvent {
        var progress = state.expertise[area, default: SkillProgress()]
        progress.addExperience(amount)
        state.expertise[area] = progress
        state.skills[area] = progress.level
        return .experienceGained(area: area, amount: amount, level: progress.level)
    }

    private func workmanship(for score: Int) -> WorkmanshipQuality {
        score >= 82 ? .good : (score >= 55 ? .acceptable : .poor)
    }

    private func laborValue(for job: RepairJob) -> Money {
        if job.serviceKind == .periodicMaintenance {
            return Money(minorUnits: Int64(180_000 + job.maintenanceTasks.count * 55_000))
        }
        guard let faultID = job.diagnosedFaultID, let fault = catalog.fault(id: faultID) else { return .zero }
        return fault.laborValue
    }

    private mutating func applyReputation(
        for quality: WorkmanshipQuality,
        strategy: PriceStrategy,
        concealed: Bool,
        noticed: Bool
    ) {
        switch quality {
        case .good:
            state.reputation.craftsmanship += 4
            state.reputation.trust += strategy == .affordable || strategy == .fair ? 3 : 1
        case .acceptable:
            state.reputation.craftsmanship += 1
        case .poor:
            state.reputation.craftsmanship -= 5
            state.reputation.trust -= 3
        }
        if strategy == .excessive { state.reputation.suspicion += 5 }
        if concealed { state.reputation.suspicion += 6 }
        if noticed { state.reputation.trust -= 5; state.reputation.suspicion += 4 }
        state.reputation.clamp()
    }

    private mutating func makeReview(
        for job: RepairJob,
        workmanship: WorkmanshipQuality,
        strategy: PriceStrategy,
        noticed: Bool,
        random: inout SeededRandomSource
    ) -> ShopReview? {
        let tone: ReviewTone
        var stars: Int
        if noticed || workmanship == .poor {
            tone = .negative
            stars = noticed && workmanship == .poor ? 1 : 2
        } else if workmanship == .good && (strategy == .affordable || strategy == .fair) {
            tone = .positive
            stars = 5
        } else {
            tone = .neutral
            stars = strategy == .excessive ? 3 : 4
        }
        if job.isWashed, !noticed, workmanship != .poor {
            stars = min(5, stars + 1)
        }
        let chance = tone == .neutral ? 45 : 78
        guard random.next(upperBound: 100) < chance else { return nil }
        let templates = catalog.reviews.filter { $0.tone == tone }
        let fallback: String
        switch tone {
        case .positive: fallback = "İşi temiz yaptı, fiyatı da baştan düşündüğüm gibiydi."
        case .neutral: fallback = "İş görüldü, biraz bekledim ama araç düzeldi."
        case .negative: fallback = "Fiyat sonradan değişti; bir daha gelmeden önce iki kere düşünürüm."
        }
        let text = templates.isEmpty ? fallback : templates[random.next(upperBound: templates.count)].text
        return ShopReview(id: random.nextUUID(), customerID: job.customerID, stars: stars, text: text, day: state.day)
    }

    private mutating func addReview(_ review: ShopReview) {
        let weight = min(20, 5 + state.reviews.count)
        state.ratingTenths = min(50, max(10, (state.ratingTenths * weight + review.stars * 10) / (weight + 1)))
        state.reviews.append(review)
        if state.reviews.count > 30 { state.reviews.removeFirst(state.reviews.count - 30) }
    }

    private mutating func scheduleConsequences(
        for job: RepairJob,
        paid: Money,
        quality: WorkmanshipQuality,
        partQuality: PartQuality,
        strategy: PriceStrategy,
        concealed: Bool,
        noticed: Bool,
        random: inout SeededRandomSource
    ) {
        let risky = quality == .poor || partQuality == .used || strategy == .excessive || concealed || noticed
        if risky && random.next(upperBound: 100) < 62 {
            let isInspection = state.reputation.suspicion > 35
            let inspectionMessages = [
                "Esnaf denetimi geldi. Parça alış kaydıyla müşteriye anlatılan kalite uyuşmayınca tutanak ve ceza çıktı.",
                "Denetçi rafı, fişi ve sökülen parçayı yan yana koydu: ‘Usta, bu hesap lifte sığmıyor.’ Ceza kesildi.",
                "Şikâyet üzerine dükkân kayıtları incelendi. Belgesiz işlem ve fiyat farkı için idari ceza uygulandı.",
                "Denetim ekibi ‘yan sanayi’ kutusunu açıp faturadaki ‘orijinal’ satırını gördü. Açıklama yetmedi, ceza çıktı.",
                "Sanayi odasından kontrol geldi. Garanti ve parça bilgisi eksik olduğu için tutanak tutuldu.",
                "Denetçi tezgâhtaki kutuyla stok kaydını eşleştiremedi. ‘Bu parça nereden geldi?’ sorusu cezayla kapandı.",
                "Müşteri beyanıyla iş emri karşılaştırıldı. Onay alınmadan eklenen işlem için para cezası uygulandı.",
                "Kontrolde eski parçanın müşteriye gösterilmediği ve kalite bilgisinin saklandığı belirlendi. Tutanak tutuldu.",
                "Garanti sözü kayıtlarda bulunamayınca denetçi kalemi bırakmadı. Dükkâna ceza ve uyarı yazıldı.",
                "Fiyat listesiyle kasadaki tahsilat birbirini tutmadı. Denetim, aradaki farkı ustaya masraf olarak geri yazdı."
            ]
            let complaintMessages = [
                "Müşteri aynı sesle geri geldi: ‘Usta radyoyu açınca geçiyor demiştin, radyo da bozuldu.’ Telafi masrafı çıktı.",
                "Takılan parça iki gün sonra sorun çıkardı; müşteri çayı bu kez şekersiz içti. Ücretsiz düzeltme yapıldı.",
                "Müşteri başka dükkândan aldığı fiyatı gösterdi. Fazla alınan kısmın bir bölümü iade edildi.",
                "Araç yolda tekrar arıza verince çekiciyle kapıya geldi. Çekici ve telafi bedeli dükkâna yazıldı.",
                "Gizlenen çıkma parça başka ustanın kontrolünde ortaya çıktı. Müşteri iade ve yeniden onarım istedi.",
                "Telefon sabah erkenden çaldı: ‘Usta ses gitti ama lambalar kurul yaptı.’ Araç yeniden işleme alındı.",
                "Müşteri sökülen parçanın fotoğrafını istedi; anlatılanla takılan uyuşmayınca ücret iadesi yapıldı.",
                "Araç ilk rampada yine bağırmaya başladı. Müşteri ‘Ben motor sesi değil yol almak istemiştim’ diyerek geri döndü.",
                "Tamponun köşesi ilk kasiste yeniden ayrıldı. Bant değil işçilik isteyen müşteriye ücretsiz düzeltme yapıldı.",
                "Kapı bu kez kapandı ama cam sürtme sesi yaptı. Eksik ayar için araç yeniden lifte alındı."
            ]
            state.consequences.append(ScheduledConsequence(
                id: random.nextUUID(),
                dueDay: state.day + 1 + random.next(upperBound: 3),
                kind: isInspection ? .inspection : .complaint,
                amount: percent(paid, isInspection ? 45 : 20),
                message: isInspection
                    ? inspectionMessages[random.next(upperBound: inspectionMessages.count)]
                    : complaintMessages[random.next(upperBound: complaintMessages.count)]
            ))
        }
    }

    private mutating func makeAuction() -> AuctionState {
        var random = SeededRandomSource(seed: state.randomSeed)
        let chosenVehicles = catalog.vehicles.shuffledDeterministically(using: &random).prefix(3)
        let lots = chosenVehicles.map { vehicle -> AuctionLot in
            let faultCount = min(catalog.faults.count, 3 + random.next(upperBound: 3))
            let faults = Array(catalog.faults.shuffledDeterministically(using: &random).prefix(faultCount))
            let impactSide = random.next(upperBound: 2)
            let panelDamages = VehiclePanel.allCases.enumerated().map { index, panel -> PanelDamage in
                let roll = random.next(upperBound: 100)
                let isImpactPanel = index % 2 == impactSide && index < 12
                let condition: PanelCondition
                if panel == .chassis && roll < 62 {
                    condition = .heavyDamage
                } else if isImpactPanel && roll < 72 {
                    condition = roll < 30 ? .heavyDamage : .damaged
                } else if roll < 18 {
                    condition = .replaced
                } else if roll < 34 {
                    condition = .painted
                } else {
                    condition = .original
                }
                return PanelDamage(panel: panel, condition: condition)
            }
            let fixedPrice = percent(vehicle.baseValue, 18 + random.next(upperBound: 15))
            return AuctionLot(
                id: random.nextUUID(),
                vehicleID: vehicle.id,
                visibleFaultID: faults.first?.id ?? catalog.faults[0].id,
                hiddenFaultIDs: Array(faults.dropFirst().map(\.id)),
                currentBid: fixedPrice,
                competitorMaximum: fixedPrice,
                fixedPrice: fixedPrice,
                severity: random.next(upperBound: 100) < 38 ? .totalLoss : .heavy,
                panelDamages: panelDamages,
                mechanicalFaultIDs: faults.map(\.id),
                airbagsDeployed: random.next(upperBound: 100) < 72,
                startsAndDrives: random.next(upperBound: 100) < 43,
                recordedDamage: percent(vehicle.baseValue, 45 + random.next(upperBound: 36))
            )
        }
        state.randomSeed = random.state
        return AuctionState(lots: lots)
    }

    private func supports(_ facility: ShopFacility) -> Bool {
        catalog.shopLevel(state.shopLevel)?.facilities.contains(facility) == true
    }

    private mutating func recordFinance(amount: Money, category: FinanceCategory, note: String) {
        let ordinal = UInt64(state.financeEntries.count + 1)
        let dayValue = UInt32(max(0, state.day))
        let id = UUID(uuid: (
            0x46, 0x49, 0x4E, 0x41,
            UInt8((dayValue >> 24) & 0xFF), UInt8((dayValue >> 16) & 0xFF),
            UInt8((dayValue >> 8) & 0xFF), UInt8(dayValue & 0xFF),
            UInt8((ordinal >> 56) & 0xFF), UInt8((ordinal >> 48) & 0xFF),
            UInt8((ordinal >> 40) & 0xFF), UInt8((ordinal >> 32) & 0xFF),
            UInt8((ordinal >> 24) & 0xFF), UInt8((ordinal >> 16) & 0xFF),
            UInt8((ordinal >> 8) & 0xFF), UInt8(ordinal & 0xFF)
        ))
        state.financeEntries.append(FinanceEntry(
            id: id,
            day: state.day,
            category: category,
            amount: amount,
            note: note
        ))
    }

    private func percent(_ money: Money, _ value: Int) -> Money {
        Money(minorUnits: money.minorUnits * Int64(value) / 100)
    }
}

private extension Array {
    func shuffledDeterministically(using random: inout SeededRandomSource) -> [Element] {
        guard count > 1 else { return self }
        var result = self
        for index in stride(from: result.count - 1, through: 1, by: -1) {
            let other = random.next(upperBound: index + 1)
            if index != other { result.swapAt(index, other) }
        }
        return result
    }
}
