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
        var events: [GameEvent]
        switch command {
        case .prepareDay:
            events = prepareDay()
        case .acceptOffer(let id):
            events = try acceptOffer(id)
        case .diagnose(let jobID, let faultID):
            events = try diagnose(jobID: jobID, faultID: faultID)
        case .setQuote(let jobID, let strategy, let hidePartQuality):
            events = try setQuote(jobID: jobID, strategy: strategy, hidePartQuality: hidePartQuality)
        case .buyPart(let jobID, let quality):
            events = try buyPart(jobID: jobID, quality: quality)
        case .completeRepair(let jobID, let performance):
            events = try completeRepair(jobID: jobID, performance: performance)
        case .endDay:
            events = endDay()
        case .upgradeShop:
            events = try upgradeShop()
        case .inspectAuctionLot(let id):
            events = try inspectAuctionLot(id)
        case .placeAuctionBid(let lotID, let amount):
            events = try placeAuctionBid(lotID: lotID, amount: amount)
        case .advanceAuctionRound:
            events = try advanceAuctionRound()
        case .repairProjectCar(let projectID, let performance):
            events = try repairProjectCar(projectID: projectID, performance: performance)
        case .sellProjectCar(let projectID, let honest):
            events = try sellProjectCar(projectID: projectID, honest: honest)
        case .grantPurchase(let transactionID, let cash, let themeID):
            events = grantPurchase(transactionID: transactionID, cash: cash, themeID: themeID)
        }

        state.parentRevision = state.revision
        state.revision += 1
        state.modifiedAt = Date()
        return events
    }

    private mutating func prepareDay() -> [GameEvent] {
        guard state.offers.isEmpty else { return [] }
        var random = SeededRandomSource(seed: state.randomSeed)
        var offers: [CustomerOffer] = []

        let unlockedVehicleCount = min(catalog.vehicles.count, state.shopLevel == 1 ? 3 : (state.shopLevel == 2 ? 5 : 6))
        let availableVehicles = Array(catalog.vehicles.prefix(unlockedVehicleCount))
        guard !catalog.customers.isEmpty, !availableVehicles.isEmpty, !catalog.faults.isEmpty else {
            return []
        }

        for _ in 0..<3 {
            let customer = catalog.customers[random.next(upperBound: catalog.customers.count)]
            let vehicle = availableVehicles[random.next(upperBound: availableVehicles.count)]
            let actualFault = catalog.faults[random.next(upperBound: catalog.faults.count)]
            var candidates = [actualFault.id]
            let alternatives = catalog.faults.filter { $0.id != actualFault.id }.shuffledDeterministically(using: &random)
            candidates.append(contentsOf: alternatives.prefix(2).map(\.id))
            candidates = candidates.shuffledDeterministically(using: &random)
            offers.append(CustomerOffer(
                id: random.nextUUID(),
                customerID: customer.id,
                vehicleID: vehicle.id,
                actualFaultID: actualFault.id,
                suspectedFaultIDs: candidates,
                complaint: actualFault.complaint
            ))
        }

        state.randomSeed = random.state
        state.offers = offers
        var events: [GameEvent] = [.dayPrepared(state.day)]
        if state.day <= 3 {
            events.append(.tutorial(tutorialMessage(for: state.day)))
        }
        return events
    }

    private mutating func acceptOffer(_ id: UUID) throws -> [GameEvent] {
        guard let index = state.offers.firstIndex(where: { $0.id == id }) else {
            throw GameRuleError.invalidCommand("Bu müşteri teklifi artık geçerli değil.")
        }
        let capacity = catalog.shopLevel(state.shopLevel)?.capacity ?? 1
        guard state.activeJobs.count + state.projectCars.count < capacity else {
            throw GameRuleError.shopIsFull
        }
        let offer = state.offers.remove(at: index)
        state.activeJobs.append(RepairJob(offer: offer))
        return [.offerAccepted(id)]
    }

    private mutating func diagnose(jobID: UUID, faultID: String) throws -> [GameEvent] {
        guard catalog.fault(id: faultID) != nil else { throw GameRuleError.contentMissing(faultID) }
        guard let index = state.activeJobs.firstIndex(where: { $0.id == jobID }),
              state.activeJobs[index].stage == .awaitingDiagnosis else {
            throw GameRuleError.invalidCommand("Bu araç şu anda teşhis beklemiyor.")
        }
        try spendTime(1)
        state.activeJobs[index].diagnosedFaultID = faultID
        let correct = state.activeJobs[index].actualFaultID == faultID
        if correct {
            state.activeJobs[index].stage = .awaitingQuote
        } else {
            state.activeJobs[index].diagnosedFaultID = nil
            state.reputation.craftsmanship -= 1
            state.reputation.clamp()
        }
        return [.diagnosisCompleted(correct: correct), .reputationChanged(state.reputation)]
    }

    private mutating func setQuote(jobID: UUID, strategy: PriceStrategy, hidePartQuality: Bool) throws -> [GameEvent] {
        guard let index = state.activeJobs.firstIndex(where: { $0.id == jobID }),
              state.activeJobs[index].stage == .awaitingQuote,
              let diagnosedID = state.activeJobs[index].diagnosedFaultID,
              let fault = catalog.fault(id: diagnosedID) else {
            throw GameRuleError.invalidCommand("Önce teşhisi tamamlamalısın.")
        }
        let base = fault.basePartCost + fault.laborValue
        let quote = percent(base, strategy.multiplierPercent)
        state.activeJobs[index].strategy = strategy
        state.activeJobs[index].hidePartQuality = hidePartQuality
        state.activeJobs[index].quote = quote
        state.activeJobs[index].stage = .awaitingPart
        return [.quotePrepared(quote)]
    }

    private mutating func buyPart(jobID: UUID, quality: PartQuality) throws -> [GameEvent] {
        guard let index = state.activeJobs.firstIndex(where: { $0.id == jobID }),
              state.activeJobs[index].stage == .awaitingPart,
              let diagnosedID = state.activeJobs[index].diagnosedFaultID,
              let fault = catalog.fault(id: diagnosedID) else {
            throw GameRuleError.invalidCommand("Bu iş için henüz parça seçilemez.")
        }
        let cost = percent(fault.basePartCost, quality.costPercent)
        let creditLimit = Money(minorUnits: -1_000_000)
        guard state.cash - cost >= creditLimit else { throw GameRuleError.notEnoughMoney }
        try spendTime(1)
        state.cash = state.cash - cost
        state.activeJobs[index].partQuality = quality
        state.activeJobs[index].stage = .readyForRepair
        state.inventory.append(InventoryItem(
            id: state.activeJobs[index].id,
            jobID: state.activeJobs[index].id,
            faultID: diagnosedID,
            partName: fault.partName,
            quality: quality,
            purchasePrice: cost
        ))
        return [.moneyChanged(Money(minorUnits: -cost.minorUnits), reason: "\(quality.title) \(fault.partName)")]
    }

    private mutating func completeRepair(jobID: UUID, performance: Int) throws -> [GameEvent] {
        guard let index = state.activeJobs.firstIndex(where: { $0.id == jobID }),
              state.activeJobs[index].stage == .readyForRepair,
              let partQuality = state.activeJobs[index].partQuality,
              let quote = state.activeJobs[index].quote,
              let strategy = state.activeJobs[index].strategy,
              let actualFault = catalog.fault(id: state.activeJobs[index].actualFaultID) else {
            throw GameRuleError.invalidCommand("Araç tamire hazır değil.")
        }
        try spendTime(2)
        var random = SeededRandomSource(seed: state.randomSeed)
        let job = state.activeJobs[index]
        let skill = state.skills[actualFault.area, default: 1]
        let equipment = catalog.shopLevel(state.shopLevel)?.equipmentBonus ?? 0
        let diagnosisBonus = job.diagnosedFaultID == job.actualFaultID ? 10 : -45
        let jitter = random.next(upperBound: 11) - 5
        let total = max(0, min(100, performance + skill * 4 + equipment + diagnosisBonus + (partQuality.reliabilityScore - 70) / 3 + jitter))
        state.randomSeed = random.state
        let quality: WorkmanshipQuality = total >= 78 ? .good : (total >= 48 ? .acceptable : .poor)

        state.cash = state.cash + quote
        state.skills[actualFault.area] = min(10, skill + 1)
        applyReputation(for: quality, strategy: strategy, concealed: job.hidePartQuality)
        scheduleConsequences(for: job, quality: quality, partQuality: partQuality, strategy: strategy, random: &random)
        state.randomSeed = random.state
        state.inventory.removeAll { $0.jobID == jobID }
        state.activeJobs.remove(at: index)

        return [
            .repairCompleted(quality),
            .moneyChanged(quote, reason: "Müşteri ödemesi"),
            .reputationChanged(state.reputation)
        ]
    }

    private mutating func endDay() -> [GameEvent] {
        state.cash = state.cash - catalog.balance.dailyExpense
        var events: [GameEvent] = [
            .moneyChanged(Money(minorUnits: -catalog.balance.dailyExpense.minorUnits), reason: "Günlük dükkân gideri")
        ]
        if state.cash < Money(minorUnits: -500_000) {
            let support = Money(minorUnits: -200_000 - state.cash.minorUnits)
            state.cash = state.cash + support
            events.append(.consequence("Parçacı veresiye defterini açtı: ‘İşi çevir usta, haftaya konuşuruz.’ Kasa yeniden çalışabilecek seviyeye geldi."))
        }

        let due = state.consequences.filter { $0.dueDay <= state.day }
        state.consequences.removeAll { $0.dueDay <= state.day }
        for consequence in due {
            switch consequence.kind {
            case .complaint, .comeback:
                state.cash = state.cash - consequence.amount
                state.reputation.trust -= 4
                state.reputation.craftsmanship -= 2
            case .inspection:
                state.cash = state.cash - consequence.amount
                state.reputation.suspicion -= 8
                state.reputation.trust -= 3
            case .referral:
                state.reputation.trust += 3
                state.cash = state.cash + consequence.amount
            }
            state.reputation.clamp()
            events.append(.consequence(consequence.message))
        }

        state.day += 1
        state.remainingSlots = catalog.balance.daySlots
        state.offers = []
        if state.day >= 4 && (state.day - 4).isMultiple(of: 3) {
            state.auction = makeAuction()
            events.append(.auctionOpened)
        } else {
            state.auction = nil
        }
        events.append(.dayEnded(state.day - 1))
        events.append(contentsOf: prepareDay())
        return events
    }

    private mutating func upgradeShop() throws -> [GameEvent] {
        let nextLevel = state.shopLevel + 1
        guard let definition = catalog.shopLevel(nextLevel) else {
            throw GameRuleError.invalidCommand("Dükkân zaten en yüksek seviyede.")
        }
        guard state.cash >= definition.upgradeCost else { throw GameRuleError.notEnoughMoney }
        state.cash = state.cash - definition.upgradeCost
        state.shopLevel = nextLevel
        return [
            .moneyChanged(Money(minorUnits: -definition.upgradeCost.minorUnits), reason: "Dükkân yükseltmesi"),
            .shopUpgraded(nextLevel)
        ]
    }

    private mutating func inspectAuctionLot(_ id: UUID) throws -> [GameEvent] {
        guard state.cash >= catalog.balance.inspectionCost else { throw GameRuleError.notEnoughMoney }
        guard var auction = state.auction,
              let index = auction.lots.firstIndex(where: { $0.id == id }) else {
            throw GameRuleError.invalidCommand("İncelenecek ihale aracı bulunamadı.")
        }
        let unrevealed = auction.lots[index].hiddenFaultIDs.filter { !auction.lots[index].revealedFaultIDs.contains($0) }
        guard let fault = unrevealed.first else {
            throw GameRuleError.invalidCommand("Bu araç için ekspertizin göstereceği başka kusur kalmadı.")
        }
        try spendTime(1)
        state.cash = state.cash - catalog.balance.inspectionCost
        auction.lots[index].revealedFaultIDs.append(fault)
        state.auction = auction
        return [.moneyChanged(Money(minorUnits: -catalog.balance.inspectionCost.minorUnits), reason: "İhale ekspertizi")]
    }

    private mutating func placeAuctionBid(lotID: UUID, amount: Money) throws -> [GameEvent] {
        guard amount <= state.cash else { throw GameRuleError.notEnoughMoney }
        guard var auction = state.auction,
              let index = auction.lots.firstIndex(where: { $0.id == lotID }) else {
            throw GameRuleError.invalidCommand("İhale açık değil.")
        }
        guard !auction.lots.enumerated().contains(where: { $0.offset != index && $0.element.playerIsHighest }) else {
            throw GameRuleError.invalidCommand("Aynı ihalede yalnızca bir araca lider teklif verebilirsin.")
        }
        guard amount.minorUnits >= auction.lots[index].currentBid.minorUnits + 50_000 else {
            throw GameRuleError.invalidCommand("Yeni teklif en az 500 ₺ artırılmalı.")
        }
        auction.lots[index].currentBid = amount
        auction.lots[index].playerIsHighest = true
        state.auction = auction
        return []
    }

    private mutating func advanceAuctionRound() throws -> [GameEvent] {
        guard var auction = state.auction else {
            throw GameRuleError.invalidCommand("Şu anda açık ihale yok.")
        }
        var random = SeededRandomSource(seed: state.randomSeed)
        for index in auction.lots.indices where auction.lots[index].playerIsHighest {
            let increment = Money(minorUnits: Int64(50_000 + random.next(upperBound: 4) * 25_000))
            let competitorBid = auction.lots[index].currentBid + increment
            if competitorBid <= auction.lots[index].competitorMaximum {
                auction.lots[index].currentBid = competitorBid
                auction.lots[index].playerIsHighest = false
            }
        }
        state.randomSeed = random.state

        guard auction.round >= 3 else {
            auction.round += 1
            state.auction = auction
            return [.auctionRoundAdvanced(auction.round)]
        }

        var events: [GameEvent] = []
        if let won = auction.lots.first(where: \.playerIsHighest), won.currentBid <= state.cash {
            let capacity = catalog.shopLevel(state.shopLevel)?.capacity ?? 1
            if state.activeJobs.count + state.projectCars.count < capacity {
                state.cash = state.cash - won.currentBid
                let project = ProjectCar(
                    id: won.id,
                    vehicleID: won.vehicleID,
                    faultIDs: [won.visibleFaultID] + won.hiddenFaultIDs,
                    purchasePrice: won.currentBid
                )
                state.projectCars.append(project)
                let name = catalog.vehicle(id: won.vehicleID)?.name ?? "İhale aracı"
                events.append(.auctionWon(vehicleName: name, price: won.currentBid))
                events.append(.moneyChanged(Money(minorUnits: -won.currentBid.minorUnits), reason: "İhale aracı"))
            } else {
                events.append(.consequence("Aracı kazandın ama dükkânda yer olmadığı için ihale teminatın iade edildi."))
            }
        }
        state.auction = nil
        return events
    }

    private mutating func repairProjectCar(projectID: UUID, performance: Int) throws -> [GameEvent] {
        guard let index = state.projectCars.firstIndex(where: { $0.id == projectID }),
              state.projectCars[index].stage == .awaitingRepair else {
            throw GameRuleError.invalidCommand("Bu proje araç tamir beklemiyor.")
        }
        let faults = state.projectCars[index].faultIDs.compactMap { catalog.fault(id: $0) }
        let totalBase = faults.reduce(Money.zero) { $0 + $1.basePartCost }
        let restorationCost = percent(totalBase, 85)
        guard state.cash >= restorationCost else { throw GameRuleError.notEnoughMoney }
        try spendTime(3)
        state.cash = state.cash - restorationCost
        let averageSkill = faults.isEmpty ? 1 : faults.reduce(0) { $0 + state.skills[$1.area, default: 1] } / faults.count
        state.projectCars[index].restorationQuality = min(100, max(20, performance + averageSkill * 3))
        state.projectCars[index].stage = .readyForSale
        return [
            .moneyChanged(Money(minorUnits: -restorationCost.minorUnits), reason: "Restorasyon parçaları"),
            .projectCarReady(projectID)
        ]
    }

    private mutating func sellProjectCar(projectID: UUID, honest: Bool) throws -> [GameEvent] {
        guard let index = state.projectCars.firstIndex(where: { $0.id == projectID }),
              state.projectCars[index].stage == .readyForSale,
              let vehicle = catalog.vehicle(id: state.projectCars[index].vehicleID) else {
            throw GameRuleError.invalidCommand("Bu araç henüz satışa hazır değil.")
        }
        let project = state.projectCars[index]
        let honestPercent = 65 + project.restorationQuality / 2
        let salePrice = percent(vehicle.baseValue, honest ? honestPercent : honestPercent + 18)
        state.cash = state.cash + salePrice
        if honest {
            state.reputation.trust += 3
        } else {
            state.reputation.suspicion += 8
            if project.restorationQuality < 80 {
                state.consequences.append(ScheduledConsequence(
                    id: project.id,
                    dueDay: state.day + 2,
                    kind: .complaint,
                    amount: percent(salePrice, 15),
                    message: "İhale arabasının alıcısı aradı: ‘Usta, bu araba düz giderken niye viraj sesi çıkarıyor?’"
                ))
            }
        }
        state.reputation.clamp()
        state.projectCars.remove(at: index)
        return [.projectCarSold(price: salePrice, honest: honest), .reputationChanged(state.reputation)]
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

    private mutating func spendTime(_ amount: Int) throws {
        guard state.remainingSlots >= amount else { throw GameRuleError.notEnoughTime }
        state.remainingSlots -= amount
    }

    private mutating func applyReputation(for quality: WorkmanshipQuality, strategy: PriceStrategy, concealed: Bool) {
        switch quality {
        case .good:
            state.reputation.craftsmanship += 4
            state.reputation.trust += strategy == .fair ? 3 : 1
        case .acceptable:
            state.reputation.craftsmanship += 1
        case .poor:
            state.reputation.craftsmanship -= 5
            state.reputation.trust -= 3
        }
        if strategy == .excessive { state.reputation.suspicion += 5 }
        if concealed { state.reputation.suspicion += 6 }
        state.reputation.clamp()
    }

    private mutating func scheduleConsequences(
        for job: RepairJob,
        quality: WorkmanshipQuality,
        partQuality: PartQuality,
        strategy: PriceStrategy,
        random: inout SeededRandomSource
    ) {
        let risky = quality == .poor || partQuality == .used || strategy == .excessive || job.hidePartQuality
        if risky && random.next(upperBound: 100) < 62 {
            let quote = job.quote ?? .zero
            state.consequences.append(ScheduledConsequence(
                id: random.nextUUID(),
                dueDay: state.day + 1 + random.next(upperBound: 3),
                kind: state.reputation.suspicion > 35 ? .inspection : .complaint,
                amount: percent(quote, state.reputation.suspicion > 35 ? 45 : 20),
                message: state.reputation.suspicion > 35
                    ? "Esnaf odasından geldiler. Çayı beğendiler ama faturaları pek beğenmediler."
                    : "Müşteri geri döndü: ‘Usta ses kesildi ama araba şimdi sessizliğe alışamadı galiba.’"
            ))
        } else if quality == .good && strategy == .fair && random.next(upperBound: 100) < 45 {
            state.consequences.append(ScheduledConsequence(
                id: random.nextUUID(),
                dueDay: state.day + 1,
                kind: .referral,
                amount: Money(minorUnits: 40_000),
                message: "Memnun müşteri iki komşusuna seni önermiş; bahşiş niyetine küçük bir iş geldi."
            ))
        }
    }

    private mutating func makeAuction() -> AuctionState {
        var random = SeededRandomSource(seed: state.randomSeed)
        let chosenVehicles = catalog.vehicles.shuffledDeterministically(using: &random).prefix(3)
        let lots = chosenVehicles.map { vehicle -> AuctionLot in
            let selectedFaults = catalog.faults.shuffledDeterministically(using: &random).prefix(3)
            let faults = Array(selectedFaults)
            let opening = percent(vehicle.baseValue, 22 + random.next(upperBound: 9))
            let maximum = percent(vehicle.baseValue, 43 + random.next(upperBound: 15))
            return AuctionLot(
                id: random.nextUUID(),
                vehicleID: vehicle.id,
                visibleFaultID: faults.first?.id ?? catalog.faults[0].id,
                hiddenFaultIDs: Array(faults.dropFirst().map(\.id)),
                currentBid: opening,
                competitorMaximum: maximum
            )
        }
        state.randomSeed = random.state
        return AuctionState(lots: lots)
    }

    private func tutorialMessage(for day: Int) -> String {
        switch day {
        case 1: "Ustan: Önce dinle, sonra anahtara uzan. Müşterinin dediği arıza ile arabanın dediği her zaman aynı değildir."
        case 2: "Ustan: Parçanın ucuzu kasayı sevindirir; geri gelen araba bütün günü yer."
        default: "Ustan: Fiyatı sen söylersin ama namını müşteri söyler. Yarın ihaleye de bir göz atarsın."
        }
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
