import GameDomain

extension GameEngine {
    mutating func processLoanPayments() -> [GameEvent] {
        var events = settleOverdueBalances()

        for index in state.loans.indices {
            while state.loans[index].nextPaymentMinute <= state.totalMinutes,
                  state.loans[index].remainingInstallments > 0,
                  state.loans[index].remainingBalance > state.loans[index].overdueBalance {
                let scheduledBalance = state.loans[index].remainingBalance - state.loans[index].overdueBalance
                let payment = min(state.loans[index].installmentAmount, scheduledBalance)
                state.loans[index].remainingInstallments -= 1
                state.loans[index].nextPaymentMinute += state.loans[index].installmentIntervalMinutes

                if state.cash >= payment {
                    events.append(contentsOf: payLoanBalance(at: index, amount: payment, note: "Kredi taksiti"))
                } else {
                    state.loans[index].overdueBalance = state.loans[index].overdueBalance + payment
                    let message = "\(state.loans[index].plan.title) taksiti ödenemedi. Gecikmiş Borç \(state.loans[index].overdueBalance.liraText)."
                    recordIncident(kind: .loan, message: message, cashImpact: .zero)
                    events.append(.consequence(message))
                }
            }
        }

        while BankingRules.totalOverdue(for: state) >= BankingRules.crisisThreshold,
              let liquidationEvents = liquidateOneCrisisAsset() {
            events.append(contentsOf: liquidationEvents)
            events.append(contentsOf: settleOverdueBalances())
        }

        if BankingRules.totalOverdue(for: state) >= BankingRules.crisisThreshold {
            events.append(contentsOf: restructureDebt())
        }

        var index = state.loans.count - 1
        while index >= 0, !state.loans.isEmpty {
            if state.loans[index].remainingBalance <= .zero {
                let id = state.loans[index].id
                state.loans.remove(at: index)
                events.append(.loanClosed(id))
            }
            index -= 1
        }
        return events
    }

    private mutating func settleOverdueBalances() -> [GameEvent] {
        guard state.cash > .zero else { return [] }
        var events: [GameEvent] = []
        for index in state.loans.indices where state.cash > .zero && state.loans[index].overdueBalance > .zero {
            let payment = min(state.cash, state.loans[index].overdueBalance)
            state.loans[index].overdueBalance = state.loans[index].overdueBalance - payment
            events.append(contentsOf: payLoanBalance(at: index, amount: payment, note: "Gecikmiş kredi ödemesi"))
        }
        return events
    }

    private mutating func payLoanBalance(at index: Int, amount: Money, note: String) -> [GameEvent] {
        state.cash = state.cash - amount
        state.loans[index].remainingBalance = state.loans[index].remainingBalance - amount
        let cashImpact = Money(minorUnits: -amount.minorUnits)
        recordFinance(amount: cashImpact, category: .loanPayment, note: note)
        recordIncident(
            kind: .loan,
            message: "\(note) yapıldı. Kalan borç \(state.loans[index].remainingBalance.liraText).",
            cashImpact: cashImpact
        )
        return [
            .moneyChanged(cashImpact, reason: note),
            .loanInstallmentPaid(amount: amount, remainingBalance: state.loans[index].remainingBalance)
        ]
    }

    private mutating func liquidateOneCrisisAsset() -> [GameEvent]? {
        if let project = state.projectCars.first {
            let vehicle = catalog.vehicle(id: project.vehicleID)
            let marketValue = vehicle.map { VehicleTradingRules.fairPrice(project: project, vehicle: $0) } ?? .zero
            let liquidationValue = max(debtPercent(project.purchasePrice, 60), debtPercent(marketValue, 50))
            state.projectCars.removeFirst()
            return recordAssetLiquidation(
                value: liquidationValue,
                note: "Gecikmiş borç için proje aracı tasfiye edildi"
            )
        }

        if state.washLevel > 0, let wash = catalog.washLevel(state.washLevel) {
            let liquidationValue = debtPercent(wash.upgradeCost, 60)
            state.washLevel -= 1
            return recordAssetLiquidation(
                value: liquidationValue,
                note: "Gecikmiş borç için \(wash.name) ekipmanı satıldı"
            )
        }

        guard state.shopLevel > 1,
              let current = catalog.shopLevel(state.shopLevel),
              let previous = catalog.shopLevel(state.shopLevel - 1),
              previous.capacity >= state.activeJobs.count,
              previous.garageCapacity >= state.projectCars.count,
              previous.maxApprentices >= state.apprentices.count else {
            return nil
        }
        let liquidationValue = debtPercent(current.upgradeCost, 50)
        state.shopLevel -= 1
        return recordAssetLiquidation(
            value: liquidationValue,
            note: "Gecikmiş borç için dükkân \(previous.name) seviyesine küçültüldü"
        )
    }

    private mutating func recordAssetLiquidation(value: Money, note: String) -> [GameEvent] {
        state.cash = state.cash + value
        recordFinance(amount: value, category: .assetLiquidation, note: note)
        recordIncident(kind: .loan, message: "\(note). Kasaya \(value.liraText) girdi.", cashImpact: value)
        return [
            .moneyChanged(value, reason: "Kriz varlık satışı"),
            .consequence("\(note). Satış bedeli gecikmiş borca aktarıldı.")
        ]
    }

    private mutating func restructureDebt() -> [GameEvent] {
        let overdue = BankingRules.totalOverdue(for: state)
        for index in state.loans.indices where state.loans[index].remainingBalance > .zero {
            state.loans[index].overdueBalance = .zero
            state.loans[index].remainingInstallments = BankingRules.restructuringInstallmentCount
            state.loans[index].installmentAmount = BankingRules.restructuredInstallment(
                for: state.loans[index].remainingBalance
            )
            state.loans[index].installmentIntervalMinutes = BankingRules.restructuringIntervalMinutes
            state.loans[index].nextPaymentMinute = state.totalMinutes + BankingRules.restructuringIntervalMinutes
            state.loans[index].isRestructured = true
        }
        let message = "\(overdue.liraText) gecikmiş borç, 24 düşük taksitli uzun vadeli plana yapılandırıldı. Yeni kredi kullanımı borç azalana kadar kapalı."
        recordIncident(kind: .loan, message: message, cashImpact: .zero)
        return [.consequence(message)]
    }
}

private func debtPercent(_ money: Money, _ value: Int64) -> Money {
    Money(minorUnits: money.minorUnits * value / 100)
}
