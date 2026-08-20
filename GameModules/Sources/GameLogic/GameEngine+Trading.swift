import Foundation
import GameDomain

extension GameEngine {
    mutating func inspectSalvageLot(
        lotID: UUID,
        kind: SalvageInspectionKind
    ) throws -> [GameEvent] {
        guard var market = state.auction,
              let index = market.lots.firstIndex(where: { $0.id == lotID }),
              !market.lots[index].performedInspections.contains(kind) else {
            throw GameRuleError.invalidCommand("Bu araçta seçilen ekspertiz kontrolü zaten yapıldı veya araç artık satışta değil.")
        }
        var lot = market.lots[index]
        var random = SeededRandomSource(seed: state.randomSeed)
        let revealedBefore = knownDefectCount(in: lot)
        let equipment = catalog.shopLevel(state.shopLevel)?.equipmentBonus ?? 0

        switch kind {
        case .body:
            lot.revealedPanelIDs.formUnion(lot.panelDamages.map(\.panel))
        case .underbody:
            let skill = state.expertise[.chassis, default: SkillProgress()].level
            let chance = min(92, 48 + skill * 9 + equipment / 2)
            for damage in lot.structuralDamages {
                let obvious = damage.condition == .cutOrWelded || damage.condition == .cracked
                if obvious || random.next(upperBound: 100) < chance {
                    lot.revealedStructuralAreas.insert(damage.area)
                }
            }
            revealFaults(
                in: &lot,
                matching: { $0.area == .chassis },
                baseChance: chance,
                random: &random
            )
        case .systems:
            let engineSkill = state.expertise[.engine, default: SkillProgress()].level
            let electricalSkill = state.expertise[.electrical, default: SkillProgress()].level
            let chance = min(92, 42 + ((engineSkill + electricalSkill) / 2) * 10 + equipment / 2)
            revealFaults(
                in: &lot,
                matching: { $0.area != .chassis },
                baseChance: chance,
                random: &random
            )
        }

        lot.performedInspections.insert(kind)
        let revealedCount = max(0, knownDefectCount(in: lot) - revealedBefore)
        market.lots[index] = lot
        state.auction = market
        state.randomSeed = random.state
        var events = advanceClock(by: kind.durationMinutes)
        events.append(.salvageInspectionCompleted(kind: kind, revealedCount: revealedCount))
        return events
    }

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
        let hiddenCount = hiddenDefectCount(in: lot)
        var events: [GameEvent] = [
            .auctionWon(vehicleName: name, price: lot.fixedPrice),
            .moneyChanged(Money(minorUnits: -lot.fixedPrice.minorUnits), reason: "Hasarlı araç alımı")
        ]
        if hiddenCount > 0 {
            let message = "Araç garaja alınınca sökümde ekspertizde görünmeyen \(hiddenCount) ek kusur ortaya çıktı."
            recordIncident(kind: .vehiclePurchase, message: message)
            events.append(.consequence(message))
        }
        return events
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
        case .mechanical(let faultID):
            catalog.fault(id: faultID).flatMap(catalog.part(for:))?.name ?? "Mekanik onarım"
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
        state.projectCars[index].buyerOffers = []
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
        state.projectCars[index].buyerOffers = []
        return [.projectListingExpired(projectID)]
    }

    mutating func processVehicleListings() -> [GameEvent] {
        var events: [GameEvent] = []
        var random = SeededRandomSource(seed: state.randomSeed)
        for index in state.projectCars.indices {
            guard state.projectCars[index].stage == .listed,
                  let askingPrice = state.projectCars[index].askingPrice,
                  let vehicle = catalog.vehicle(id: state.projectCars[index].vehicleID),
                  var nextCheck = state.projectCars[index].nextBuyerCheckMinute,
                  nextCheck <= state.totalMinutes else {
                continue
            }

            var receivedCount = 0
            while nextCheck <= state.totalMinutes, state.projectCars[index].buyerOffers.count < 4 {
                let estimate = VehicleTradingRules.listingEstimate(
                    project: state.projectCars[index],
                    vehicle: vehicle,
                    askingPrice: askingPrice,
                    ratingTenths: state.ratingTenths,
                    hasShowroom: supports(.vehicleShowroom),
                    discloseDamage: state.projectCars[index].disclosedDamage
                )
                if random.next(upperBound: 100) < estimate.saleChancePercent,
                   let offer = makeBuyerOffer(
                       project: state.projectCars[index],
                       vehicle: vehicle,
                       askingPrice: askingPrice,
                       random: &random
                   ) {
                    state.projectCars[index].buyerOffers.append(offer)
                    receivedCount += 1
                }
                nextCheck += 360
            }

            state.projectCars[index].nextBuyerCheckMinute = nextCheck
            if receivedCount > 0 {
                recordIncident(
                    kind: .listing,
                    message: "\(vehicle.name) ilanına \(receivedCount) yeni alıcı teklifi geldi. Satış için ustanın onayı bekleniyor."
                )
                events.append(.buyerOffersReceived(
                    projectID: state.projectCars[index].id,
                    count: receivedCount
                ))
            } else {
                recordIncident(
                    kind: .listing,
                    message: "\(vehicle.name) ilanına bu kontrolde ciddi teklif gelmedi; ilan yayında kalıyor."
                )
                events.append(.projectListingExpired(state.projectCars[index].id))
            }
        }
        state.randomSeed = random.state
        return events
    }

    mutating func acceptVehicleOffer(projectID: UUID, offerID: UUID) throws -> [GameEvent] {
        guard let projectIndex = state.projectCars.firstIndex(where: { $0.id == projectID }),
              state.projectCars[projectIndex].stage == .listed,
              let offer = state.projectCars[projectIndex].buyerOffers.first(where: { $0.id == offerID }) else {
            throw GameRuleError.invalidCommand("Bu alıcı teklifi artık geçerli değil.")
        }
        var random = SeededRandomSource(seed: state.randomSeed)
        let events = finalizeProjectSale(at: projectIndex, price: offer.amount, random: &random)
        state.randomSeed = random.state
        return events
    }

    mutating func rejectVehicleOffer(projectID: UUID, offerID: UUID) throws -> [GameEvent] {
        guard let projectIndex = state.projectCars.firstIndex(where: { $0.id == projectID }),
              state.projectCars[projectIndex].stage == .listed,
              let offerIndex = state.projectCars[projectIndex].buyerOffers.firstIndex(where: { $0.id == offerID }) else {
            throw GameRuleError.invalidCommand("Bu alıcı teklifi artık geçerli değil.")
        }
        let buyerName = state.projectCars[projectIndex].buyerOffers[offerIndex].buyerName
        state.projectCars[projectIndex].buyerOffers.remove(at: offerIndex)
        return [.buyerOfferRejected(name: buyerName)]
    }

    mutating func negotiateVehicleOffer(
        projectID: UUID,
        offerID: UUID,
        counterOffer: Money
    ) throws -> [GameEvent] {
        guard let projectIndex = state.projectCars.firstIndex(where: { $0.id == projectID }),
              state.projectCars[projectIndex].stage == .listed,
              let offerIndex = state.projectCars[projectIndex].buyerOffers.firstIndex(where: { $0.id == offerID }),
              let askingPrice = state.projectCars[projectIndex].askingPrice else {
            throw GameRuleError.invalidCommand("Bu alıcı teklifi artık geçerli değil.")
        }
        let offer = state.projectCars[projectIndex].buyerOffers[offerIndex]
        guard counterOffer > offer.amount, counterOffer <= askingPrice else {
            throw GameRuleError.invalidCommand("Karşı teklif, alıcının teklifinden yüksek ve ilan fiyatını aşmayacak şekilde olmalı.")
        }

        if counterOffer <= offer.maximumAmount {
            state.projectCars[projectIndex].buyerOffers[offerIndex].amount = counterOffer
            state.projectCars[projectIndex].buyerOffers[offerIndex].negotiationCount += 1
            return [.buyerNegotiationUpdated(name: offer.buyerName, price: counterOffer)]
        }

        let nearLimit = percent(offer.maximumAmount, 103)
        if counterOffer <= nearLimit {
            state.projectCars[projectIndex].buyerOffers[offerIndex].amount = offer.maximumAmount
            state.projectCars[projectIndex].buyerOffers[offerIndex].negotiationCount += 1
            return [.buyerNegotiationUpdated(name: offer.buyerName, price: offer.maximumAmount)]
        }

        state.projectCars[projectIndex].buyerOffers.remove(at: offerIndex)
        return [.buyerWalkedAway(name: offer.buyerName)]
    }

    private func makeBuyerOffer(
        project: ProjectCar,
        vehicle: VehicleDefinition,
        askingPrice: Money,
        random: inout SeededRandomSource
    ) -> VehicleBuyerOffer? {
        let usedNames = Set(project.buyerOffers.map(\.buyerName))
        let candidates = catalog.customers.filter { !usedNames.contains($0.name) }
        guard !candidates.isEmpty else { return nil }
        let buyer = candidates[random.next(upperBound: candidates.count)]
        let fairPrice = VehicleTradingRules.fairPrice(project: project, vehicle: vehicle)
        let maximumFromBudget = percent(fairPrice, 88 + random.next(upperBound: 21))
        let maximum = min(askingPrice, maximumFromBudget)
        let opening = percent(maximum, 90 + random.next(upperBound: 7))
        return VehicleBuyerOffer(
            id: random.nextUUID(),
            buyerName: buyer.name,
            amount: opening,
            maximumAmount: maximum,
            createdAtMinute: state.totalMinutes
        )
    }

    private mutating func finalizeProjectSale(
        at projectIndex: Int,
        price: Money,
        random: inout SeededRandomSource
    ) -> [GameEvent] {
        let project = state.projectCars[projectIndex]
        let vehicleName = catalog.vehicle(id: project.vehicleID)?.name ?? "Proje araç"
        state.cash = state.cash + price
        recordFinance(amount: price, category: .vehicleSale, note: vehicleName)
        if project.disclosedDamage {
            state.ratingTenths = min(50, state.ratingTenths + 3)
        } else {
            state.reputation.suspicion += 8
            if project.restorationQuality < 85 {
                state.consequences.append(ScheduledConsequence(
                    id: random.nextUUID(),
                    dueDay: state.day + 2,
                    kind: .complaint,
                    amount: percent(price, 15),
                    message: "İlanda ağır hasar geçmişi saklanan aracın alıcısı ekspertiz raporuyla geri döndü; uzlaşma bedeli çıktı."
                ))
            }
        }
        state.reputation.clamp()
        recordIncident(
            kind: .vehicleSale,
            message: project.disclosedDamage
                ? "\(vehicleName), hasar geçmişi alıcıya anlatılarak \(price.liraText) bedelle satıldı."
                : "\(vehicleName), hasar geçmişi saklanarak \(price.liraText) bedelle satıldı; sonradan geri dönüş riski oluştu.",
            cashImpact: price,
            ratingImpact: project.disclosedDamage ? 3 : 0,
            suspicionImpact: project.disclosedDamage ? 0 : 8
        )
        state.projectCars.remove(at: projectIndex)
        return [
            .projectCarSold(price: price, honest: project.disclosedDamage),
            .reputationChanged(state.reputation)
        ]
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

    private mutating func revealFaults(
        in lot: inout AuctionLot,
        matching predicate: (FaultDefinition) -> Bool,
        baseChance: Int,
        random: inout SeededRandomSource
    ) {
        for faultID in lot.mechanicalFaultIDs {
            guard let fault = catalog.fault(id: faultID), predicate(fault) else { continue }
            let knownFromSummary = faultID == lot.visibleFaultID
            let chance = min(96, baseChance + (knownFromSummary ? 12 : 0))
            if random.next(upperBound: 100) < chance, !lot.revealedFaultIDs.contains(faultID) {
                lot.revealedFaultIDs.append(faultID)
            }
        }
    }

    private func knownDefectCount(in lot: AuctionLot) -> Int {
        let panels = lot.panelDamages.filter {
            $0.condition != .original && lot.revealedPanelIDs.contains($0.panel)
        }.count
        let structure = lot.structuralDamages.filter {
            $0.condition.requiresRepair && lot.revealedStructuralAreas.contains($0.area)
        }.count
        return panels + structure + lot.revealedFaultIDs.count
    }

    private func hiddenDefectCount(in lot: AuctionLot) -> Int {
        let panels = lot.panelDamages.filter {
            $0.condition != .original && !lot.revealedPanelIDs.contains($0.panel)
        }.count
        let structure = lot.structuralDamages.filter {
            $0.condition.requiresRepair && !lot.revealedStructuralAreas.contains($0.area)
        }.count
        let knownFaults = Set(lot.revealedFaultIDs)
        let faults = lot.mechanicalFaultIDs.filter { !knownFaults.contains($0) }.count
        return panels + structure + faults
    }

}
