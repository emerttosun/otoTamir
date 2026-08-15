import Foundation
import GameDomain

extension GameEngine {
    mutating func acceptOffer(_ id: UUID) throws -> [GameEvent] {
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

    mutating func declineOffer(_ id: UUID) throws -> [GameEvent] {
        guard state.offers.contains(where: { $0.id == id }) else {
            throw GameRuleError.invalidCommand("Müşteri bulunamadı.")
        }
        state.offers.removeAll { $0.id == id }
        var events = advanceClock(by: 15)
        events.append(.customerLeft(id))
        return events
    }

    mutating func performInspection(jobID: UUID, kind: InspectionKind) throws -> [GameEvent] {
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

    mutating func diagnose(jobID: UUID, faultID: String) throws -> [GameEvent] {
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

    mutating func buyPart(jobID: UUID, quality: PartQuality) throws -> [GameEvent] {
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

    mutating func completeRepair(jobID: UUID, performance: Int) throws -> [GameEvent] {
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

    mutating func completeMaintenanceTask(
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

    mutating func setPrice(
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
            state.reputation.trust += max(1, job.washTrustBonus)
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

    mutating func washVehicle(jobID: UUID) throws -> [GameEvent] {
        guard let wash = WashBayRules.currentDefinition(for: state, catalog: catalog) else {
            throw GameRuleError.invalidCommand("Araç yıkamak için Gelişim bölümünden Yıkama Seviye 1'i açmalısın.")
        }
        guard let index = state.activeJobs.firstIndex(where: { $0.id == jobID }),
              state.activeJobs[index].stage == .awaitingPrice,
              !state.activeJobs[index].isWashed else {
            throw GameRuleError.invalidCommand("Bu araç şu anda yıkanamaz.")
        }
        let cost = wash.washCost
        guard state.cash >= cost else { throw GameRuleError.notEnoughMoney }
        state.cash = state.cash - cost
        state.activeJobs[index].isWashed = true
        state.activeJobs[index].washTrustBonus = wash.trustBonus
        recordFinance(amount: Money(minorUnits: -cost.minorUnits), category: .wash, note: wash.name)
        var events = advanceClock(by: wash.durationMinutes)
        events.append(.vehicleWashed(jobID))
        events.append(.moneyChanged(Money(minorUnits: -cost.minorUnits), reason: "Araç yıkama"))
        return events
    }

    mutating func assignApprentice(
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
        let quality = events.compactMap { event -> WorkmanshipQuality? in
            switch event {
            case .repairCompleted(let value): value
            case .apprenticeCompleted(_, let value): value
            default: nil
            }
        }.last
        recordIncident(
            kind: .apprentice,
            message: "\(apprentice.name) verilen \(task?.title ?? "tamir") işini \(quality?.title.lowercased() ?? "tamamlanmış") olarak teslim etti.",
            craftsmanshipImpact: quality == .poor ? -2 : (quality == .good ? 1 : 0)
        )
        return events
    }

}
