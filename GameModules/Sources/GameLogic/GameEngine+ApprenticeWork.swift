import Foundation
import GameDomain

extension GameEngine {
    mutating func assignApprentice(
        apprenticeID: UUID,
        jobID: UUID,
        partQuality: PartQuality
    ) throws -> [GameEvent] {
        guard let apprentice = state.apprentices.first(where: { $0.id == apprenticeID }),
              let jobIndex = state.activeJobs.firstIndex(where: { $0.id == jobID }),
              [.awaitingInspection, .awaitingDiagnosis, .awaitingPart].contains(state.activeJobs[jobIndex].stage),
              state.activeJobs[jobIndex].apprenticeWorkOrder == nil else {
            throw GameRuleError.invalidCommand("Çırak bu iş emrine atanamıyor.")
        }
        guard !state.activeJobs.contains(where: { $0.apprenticeWorkOrder?.apprenticeID == apprenticeID }) else {
            throw GameRuleError.invalidCommand("\(apprentice.name) başka bir araç üzerinde çalışıyor.")
        }
        let job = state.activeJobs[jobIndex]
        guard ApprenticeRules.canHandle(job, apprentice: apprentice, catalog: catalog) else {
            throw GameRuleError.invalidCommand("\(apprentice.name) bu işin olası arızaları için henüz yeterli seviyede değil.")
        }
        guard let order = PartPricingRules.orderDetails(for: job, catalog: catalog) else {
            throw GameRuleError.invalidCommand("Bu iş için parçacı siparişi oluşturulamadı.")
        }
        let cost = PartPricingRules.purchasePrice(
            baseCost: order.baseCost,
            quality: partQuality,
            profile: order.qualityProfile
        )
        let creditLimit = Money(minorUnits: -1_000_000)
        guard state.cash - cost >= creditLimit else { throw GameRuleError.notEnoughMoney }

        let completesAt = state.totalMinutes + ApprenticeRules.preparationDuration(
            for: job,
            apprentice: apprentice,
            catalog: catalog
        )
        state.cash = state.cash - cost
        state.activeJobs[jobIndex].partQuality = partQuality
        state.activeJobs[jobIndex].stage = .apprenticeWorking
        state.activeJobs[jobIndex].repairedByApprenticeID = apprenticeID
        state.activeJobs[jobIndex].apprenticeWorkOrder = ApprenticeWorkOrder(
            apprenticeID: apprenticeID,
            partQuality: partQuality,
            phase: .preparation,
            completesAtMinute: completesAt
        )
        state.inventory.append(InventoryItem(
            id: job.id,
            jobID: job.id,
            faultID: order.referenceID,
            partName: order.name,
            quality: partQuality,
            purchasePrice: cost
        ))
        recordFinance(
            amount: Money(minorUnits: -cost.minorUnits),
            category: .parts,
            note: "\(apprentice.name) siparişi • \(partQuality.title(for: order.qualityProfile)) \(order.name)"
        )
        return [
            .moneyChanged(Money(minorUnits: -cost.minorUnits), reason: "Çırak iş emri parça siparişi"),
            .apprenticeAssigned(name: apprentice.name, completesAtMinute: completesAt)
        ]
    }

    mutating func processApprenticeWork() -> [GameEvent] {
        var events: [GameEvent] = []
        let dueJobIDs = state.activeJobs.compactMap { job -> UUID? in
            guard let order = job.apprenticeWorkOrder,
                  let completesAt = order.completesAtMinute,
                  completesAt <= state.totalMinutes else { return nil }
            return job.id
        }
        for jobID in dueJobIDs {
            guard let index = state.activeJobs.firstIndex(where: { $0.id == jobID }),
                  let order = state.activeJobs[index].apprenticeWorkOrder,
                  let apprentice = state.apprentices.first(where: { $0.id == order.apprenticeID }) else { continue }
            switch order.phase {
            case .preparation:
                events.append(contentsOf: finishApprenticePreparation(jobIndex: index, apprentice: apprentice))
            case .repair:
                events.append(contentsOf: finishApprenticeRepair(jobIndex: index, apprentice: apprentice))
            case .waitingForPrice:
                break
            }
        }
        return events
    }

    mutating func scheduleApprenticeRepairIfNeeded(jobIndex: Int) -> [GameEvent] {
        guard var order = state.activeJobs[jobIndex].apprenticeWorkOrder,
              order.phase == .waitingForPrice,
              let apprentice = state.apprentices.first(where: { $0.id == order.apprenticeID }) else { return [] }
        let job = state.activeJobs[jobIndex]
        let baseDuration: Int
        if job.serviceKind == .periodicMaintenance {
            baseDuration = max(45, job.maintenanceTasks.count * 25)
        } else {
            let difficulty = job.actualFaultID.flatMap(catalog.fault(id:))?.requiredSkill ?? 1
            baseDuration = 90 + difficulty * 15
        }
        order.phase = .repair
        order.completesAtMinute = state.totalMinutes + ApprenticeRules.adjustedDuration(
            baseMinutes: baseDuration,
            apprentice: apprentice
        )
        state.activeJobs[jobIndex].apprenticeWorkOrder = order
        state.activeJobs[jobIndex].stage = .apprenticeWorking
        return [.apprenticeAssigned(name: apprentice.name, completesAtMinute: order.completesAtMinute ?? state.totalMinutes)]
    }

    private mutating func finishApprenticePreparation(
        jobIndex: Int,
        apprentice: Apprentice
    ) -> [GameEvent] {
        guard var order = state.activeJobs[jobIndex].apprenticeWorkOrder,
              let area = ApprenticeRules.workArea(for: state.activeJobs[jobIndex], catalog: catalog) else { return [] }
        var random = SeededRandomSource(seed: state.randomSeed)
        let performance = ApprenticeRules.performance(
            apprentice: apprentice,
            area: area,
            randomBonus: random.next(upperBound: 19)
        )
        state.randomSeed = random.state
        if performance < 55, order.preparationAttempts == 0 {
            order.preparationAttempts = 1
            order.completesAtMinute = state.totalMinutes + 30
            state.activeJobs[jobIndex].apprenticeWorkOrder = order
            return [.apprenticePreparationDelayed(
                name: apprentice.name,
                completesAtMinute: order.completesAtMinute ?? state.totalMinutes
            )]
        }

        let job = state.activeJobs[jobIndex]
        if job.serviceKind == .faultRepair, let faultID = job.actualFaultID, let fault = catalog.fault(id: faultID) {
            let inspections = Array(inferredInspections(for: fault.area).sorted { $0.rawValue < $1.rawValue }.prefix(2))
            state.activeJobs[jobIndex].performedInspections = inspections
            state.activeJobs[jobIndex].findings = inspections.map {
                fault.inspectionFindings[$0] ?? fallbackFinding(for: fault, inspection: $0)
            }
            state.activeJobs[jobIndex].candidateFaultIDs = job.suspectedFaultIDs
            state.activeJobs[jobIndex].diagnosedFaultID = faultID
        }
        order.phase = .waitingForPrice
        order.completesAtMinute = nil
        state.activeJobs[jobIndex].apprenticeWorkOrder = order
        state.activeJobs[jobIndex].stage = .awaitingPrice
        return [.apprenticeReadyForPrice(name: apprentice.name)]
    }

    private mutating func finishApprenticeRepair(
        jobIndex: Int,
        apprentice: Apprentice
    ) -> [GameEvent] {
        let job = state.activeJobs[jobIndex]
        guard let partQuality = job.partQuality else { return [] }
        var random = SeededRandomSource(seed: state.randomSeed)
        var taskEvents: [GameEvent] = []
        let areas: [SkillArea]
        if job.serviceKind == .periodicMaintenance {
            areas = job.maintenanceTasks.map(\.skillArea)
            state.activeJobs[jobIndex].completedMaintenanceTasks = job.maintenanceTasks
            taskEvents = job.maintenanceTasks.map(GameEvent.maintenanceTaskCompleted)
        } else if let faultID = job.actualFaultID, let fault = catalog.fault(id: faultID) {
            areas = [fault.area]
        } else {
            return []
        }
        let performances = areas.map { area in
            ApprenticeRules.performance(
                apprentice: apprentice,
                area: area,
                randomBonus: random.next(upperBound: 19)
            )
        }
        state.randomSeed = random.state
        let average = performances.reduce(0, +) / max(1, performances.count)
        let profile: PartQualityProfile = job.serviceKind == .periodicMaintenance ? .maintenanceSupply : .replacementPart
        let equipment = catalog.shopLevel(state.shopLevel)?.equipmentBonus ?? 0
        let score = min(100, max(0, average + equipment + (partQuality.reliabilityScore(for: profile) - 70) / 3))
        let quality = workmanship(for: score)
        state.activeJobs[jobIndex].workmanship = quality
        state.activeJobs[jobIndex].repairPerformanceTotal = performances.reduce(0, +)
        state.activeJobs[jobIndex].repairPerformanceCount = performances.count
        state.activeJobs[jobIndex].stage = .awaitingDelivery
        state.activeJobs[jobIndex].apprenticeWorkOrder = nil

        guard let apprenticeIndex = state.apprentices.firstIndex(where: { $0.id == apprentice.id }) else { return [] }
        for area in Set(areas) {
            state.apprentices[apprenticeIndex].addExperience(area: area, amount: 24 + average / 8)
        }
        let revealed = state.apprentices[apprenticeIndex].recordRepair(quality: quality)
        if quality == .good {
            state.apprentices[apprenticeIndex].customerFans.insert(job.customerID)
        }
        recordIncident(
            kind: .apprentice,
            message: "\(apprentice.name) verilen araç işini \(quality.title.lowercased()) olarak tamamladı.",
            craftsmanshipImpact: quality == .poor ? -2 : (quality == .good ? 1 : 0)
        )
        return taskEvents + [
            .repairCompleted(quality),
            .apprenticeCompleted(name: apprentice.name, quality: quality),
            .apprenticeHappinessChanged(name: apprentice.name, happiness: state.apprentices[apprenticeIndex].happiness)
        ] + revealed.map { .apprenticeTraitRevealed(name: apprentice.name, trait: $0) }
    }
}
