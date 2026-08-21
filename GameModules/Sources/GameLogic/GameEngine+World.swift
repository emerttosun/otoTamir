import Foundation
import GameDomain

extension GameEngine {
    mutating func prepareWorld() -> [GameEvent] {
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
        if state.salvageMarket == nil {
            state.salvageMarket = makeSalvageMarket()
            events.append(.salvageMarketRefreshed)
        }
        if createdInitialOffer { scheduleNextCustomer() }
        return events
    }

    mutating func advanceClock(by minutes: Int) -> [GameEvent] {
        let previousDay = state.day
        state.totalMinutes += minutes
        state.day = state.totalMinutes / 1_440 + 1
        var events: [GameEvent] = [.timeAdvanced(state.totalMinutes)]

        if state.day > previousDay {
            for newDay in (previousDay + 1)...state.day {
                events.append(contentsOf: processNewDay(newDay))
                events.append(contentsOf: processApprenticeRetention(newDay: newDay))
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
        events.append(contentsOf: processApprenticeRecruitment())
        events.append(contentsOf: processApprenticeWork())
        return events
    }

    mutating func processNewDay(_ newDay: Int) -> [GameEvent] {
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
        let due = state.consequences.filter { $0.dueDay <= newDay }
        state.consequences.removeAll { $0.dueDay <= newDay }
        for consequence in due {
            let incidentKind: IncidentKind
            let cashImpact: Money
            let ratingImpact: Int
            let craftsmanshipImpact: Int
            let suspicionImpact: Int
            switch consequence.kind {
            case .complaint, .comeback:
                incidentKind = .complaint
                cashImpact = Money(minorUnits: -consequence.amount.minorUnits)
                ratingImpact = -4
                craftsmanshipImpact = -2
                suspicionImpact = 0
                state.cash = state.cash - consequence.amount
                recordFinance(amount: cashImpact, category: .fine, note: consequence.message)
                state.ratingTenths = max(10, state.ratingTenths - 4)
                state.reputation.craftsmanship -= 2
            case .inspection:
                incidentKind = .inspection
                cashImpact = Money(minorUnits: -consequence.amount.minorUnits)
                ratingImpact = -3
                craftsmanshipImpact = 0
                suspicionImpact = -8
                state.cash = state.cash - consequence.amount
                recordFinance(amount: cashImpact, category: .fine, note: consequence.message)
                state.reputation.suspicion -= 8
                state.ratingTenths = max(10, state.ratingTenths - 3)
            case .referral:
                incidentKind = .referral
                cashImpact = consequence.amount
                ratingImpact = 3
                craftsmanshipImpact = 0
                suspicionImpact = 0
                state.ratingTenths = min(50, state.ratingTenths + 3)
                state.cash = state.cash + consequence.amount
                recordFinance(amount: consequence.amount, category: .customerIncome, note: consequence.message)
            }
            state.reputation.clamp()
            recordIncident(
                kind: incidentKind,
                message: consequence.message,
                cashImpact: cashImpact,
                ratingImpact: ratingImpact,
                craftsmanshipImpact: craftsmanshipImpact,
                suspicionImpact: suspicionImpact
            )
            events.append(.consequence(consequence.message))
        }

        if newDay >= 4, (newDay - 4).isMultiple(of: 3), state.salvageMarket == nil {
            state.salvageMarket = makeSalvageMarket()
            events.append(.salvageMarketRefreshed)
        }
        return events
    }

    mutating func upgradeShop() throws -> [GameEvent] {
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

    mutating func upgradeWashBay() throws -> [GameEvent] {
        guard let definition = WashBayRules.nextDefinition(for: state, catalog: catalog) else {
            throw GameRuleError.invalidCommand("Yıkama bölümü zaten en yüksek seviyede.")
        }
        guard state.shopLevel >= definition.requiredShopLevel else {
            throw GameRuleError.invalidCommand(
                "Yıkama Seviye \(definition.id) için dükkân en az Seviye \(definition.requiredShopLevel) olmalı."
            )
        }
        guard state.cash >= definition.upgradeCost else { throw GameRuleError.notEnoughMoney }
        state.cash = state.cash - definition.upgradeCost
        state.washLevel = definition.id
        recordFinance(
            amount: Money(minorUnits: -definition.upgradeCost.minorUnits),
            category: .shopUpgrade,
            note: "Yıkama \(definition.name)"
        )
        return [
            .moneyChanged(Money(minorUnits: -definition.upgradeCost.minorUnits), reason: "Yıkama bölümü geliştirmesi"),
            .washBayUpgraded(definition.id)
        ]
    }

    mutating func takeLoan(amount: Money, plan: LoanPlan) throws -> [GameEvent] {
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
        recordIncident(
            kind: .loan,
            message: "\(plan.title) planıyla \(amount.liraText) kredi kullanıldı. Toplam geri ödeme \(total.liraText).",
            cashImpact: amount
        )
        return [.moneyChanged(amount, reason: "Banka kredisi"), .loanTaken(amount: amount, totalRepayment: total)]
    }

}
