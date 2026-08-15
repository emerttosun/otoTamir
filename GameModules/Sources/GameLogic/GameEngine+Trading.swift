import Foundation
import GameDomain

extension GameEngine {
    mutating func purchaseAuctionLot(_ lotID: UUID) throws -> [GameEvent] {
        guard var auction = state.auction,
              let lotIndex = auction.lots.firstIndex(where: { $0.id == lotID }) else {
            throw GameRuleError.invalidCommand("Bu hasarlı araç artık satışta değil.")
        }
        let lot = auction.lots[lotIndex]
        guard lot.severity == .heavy else {
            throw GameRuleError.invalidCommand("Tam hasarlı ve hurda tescilli araç yeniden trafiğe çıkarılamaz.")
        }
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
            structuralDamages: lot.structuralDamages,
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

    mutating func completeProjectRepair(
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
        case .panel, .structural: .body
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

    func projectRepairTasks(for project: ProjectCar) -> [ProjectRepairTask] {
        project.faultIDs.map { .mechanical(faultID: $0) }
            + project.panelDamages.filter {
                VehiclePanel.exteriorCases.contains($0.panel) && $0.condition != .original
            }.map { .panel($0.panel) }
            + project.structuralDamages.filter { $0.condition.requiresRepair }.map { .structural($0.area) }
            + (project.airbagsDeployed ? [.airbag] : [])
    }

    func projectRepairTitle(_ task: ProjectRepairTask) -> String {
        switch task {
        case .mechanical(let faultID): catalog.fault(id: faultID)?.partName ?? "Mekanik onarım"
        case .panel(let panel): "\(panel.title) kaporta onarımı"
        case .structural(let area): "\(area.title) yapısal onarım"
        case .airbag: "Hava yastığı sistemi"
        }
    }

    func taskDuration(_ task: ProjectRepairTask) -> Int {
        switch task {
        case .mechanical: 60
        case .panel: 75
        case .structural: 120
        case .airbag: 60
        }
    }

    mutating func listProjectCar(
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

    mutating func cancelProjectListing(projectID: UUID) throws -> [GameEvent] {
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

    mutating func processVehicleListings() -> [GameEvent] {
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
                recordIncident(
                    kind: .vehicleSale,
                    message: project.disclosedDamage
                        ? "\(vehicle.name), hasar geçmişi alıcıya anlatılarak \(askingPrice.liraText) bedelle satıldı."
                        : "\(vehicle.name), hasar geçmişi saklanarak \(askingPrice.liraText) bedelle satıldı; sonradan geri dönüş riski oluştu.",
                    cashImpact: askingPrice,
                    trustImpact: project.disclosedDamage ? 3 : 0,
                    suspicionImpact: project.disclosedDamage ? 0 : 8
                )
                state.projectCars.remove(at: index)
                events.append(.projectCarSold(price: askingPrice, honest: project.disclosedDamage))
                events.append(.reputationChanged(state.reputation))
            } else {
                state.projectCars[index].nextBuyerCheckMinute = nextCheck
                recordIncident(
                    kind: .listing,
                    message: "\(vehicle.name) ilanı bu alıcı kontrolünde satılmadı; fiyat değiştirilebilir veya yeni alıcı beklenebilir."
                )
                events.append(.projectListingExpired(state.projectCars[index].id))
                index += 1
            }
        }
        state.randomSeed = random.state
        return events
    }

    mutating func makeAuction() -> AuctionState {
        var random = SeededRandomSource(seed: state.randomSeed)
        let chosenVehicles = catalog.vehicles.shuffledDeterministically(using: &random).prefix(3)
        let lots = chosenVehicles.map { vehicle -> AuctionLot in
            let faultCount = min(catalog.faults.count, 3 + random.next(upperBound: 3))
            let faults = Array(catalog.faults.shuffledDeterministically(using: &random).prefix(faultCount))
            let impactSide = random.next(upperBound: 2)
            let panelDamages = VehiclePanel.exteriorCases.enumerated().map { index, panel -> PanelDamage in
                let roll = random.next(upperBound: 100)
                let isImpactPanel = index % 2 == impactSide && index < 12
                let condition: PanelCondition
                if isImpactPanel && roll < 78 {
                    condition = roll < 18 ? .missing : (roll < 48 ? .heavyDamage : .damaged)
                } else if roll < 16 {
                    condition = .damaged
                } else {
                    condition = .original
                }
                return PanelDamage(panel: panel, condition: condition)
            }
            let guaranteedStructuralIndex = random.next(upperBound: StructuralArea.allCases.count)
            let structuralDamages = StructuralArea.allCases.enumerated().map { index, area -> StructuralDamage in
                let roll = random.next(upperBound: 100)
                let condition: StructuralCondition
                if index == guaranteedStructuralIndex {
                    condition = roll < 45 ? .bent : (roll < 78 ? .cracked : .cutOrWelded)
                } else if roll < 8 {
                    condition = .measurementDeviation
                } else if roll < 14 {
                    condition = .bent
                } else {
                    condition = .intact
                }
                return StructuralDamage(area: area, condition: condition)
            }
            let fixedPrice = percent(vehicle.baseValue, 12 + random.next(upperBound: 14))
            return AuctionLot(
                id: random.nextUUID(),
                vehicleID: vehicle.id,
                visibleFaultID: faults.first?.id ?? catalog.faults[0].id,
                hiddenFaultIDs: Array(faults.dropFirst().map(\.id)),
                currentBid: fixedPrice,
                competitorMaximum: fixedPrice,
                fixedPrice: fixedPrice,
                severity: .heavy,
                panelDamages: panelDamages,
                structuralDamages: structuralDamages,
                mechanicalFaultIDs: faults.map(\.id),
                airbagsDeployed: random.next(upperBound: 100) < 72,
                startsAndDrives: random.next(upperBound: 100) < 43,
                recordedDamage: percent(vehicle.baseValue, 62 + random.next(upperBound: 25))
            )
        }
        state.randomSeed = random.state
        return AuctionState(lots: lots)
    }

}
