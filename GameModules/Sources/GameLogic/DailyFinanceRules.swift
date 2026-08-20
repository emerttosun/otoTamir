import GameDomain

public struct DailyFinanceSummary: Equatable, Sendable {
    public let day: Int
    public let entries: [FinanceEntry]
    public let openingCash: Money
    public let operatingIncome: Money
    public let operatingExpense: Money
    public let operatingResult: Money
    public let newLoanProceeds: Money
    public let loanPayments: Money
    public let netCashChange: Money
    public let closingCash: Money

    public init(
        day: Int,
        entries: [FinanceEntry],
        openingCash: Money,
        operatingIncome: Money,
        operatingExpense: Money,
        operatingResult: Money,
        newLoanProceeds: Money,
        loanPayments: Money,
        netCashChange: Money,
        closingCash: Money
    ) {
        self.day = day
        self.entries = entries
        self.openingCash = openingCash
        self.operatingIncome = operatingIncome
        self.operatingExpense = operatingExpense
        self.operatingResult = operatingResult
        self.newLoanProceeds = newLoanProceeds
        self.loanPayments = loanPayments
        self.netCashChange = netCashChange
        self.closingCash = closingCash
    }
}

public enum DailyFinanceRules {
    public static func summary(for state: GameState) -> DailyFinanceSummary {
        let entries = state.financeEntries.filter { $0.day == state.day }
        let operatingEntries = entries.filter { !isFinancing($0.category) }
        let operatingIncome = operatingEntries
            .filter { $0.amount > .zero }
            .reduce(.zero) { $0 + $1.amount }
        let operatingExpense = operatingEntries
            .filter { $0.amount < .zero }
            .reduce(.zero) { $0 + Money(minorUnits: -$1.amount.minorUnits) }
        let newLoanProceeds = entries
            .filter { $0.category == .loanProceeds }
            .reduce(.zero) { $0 + max($1.amount, .zero) }
        let loanPayments = entries
            .filter { $0.category == .loanPayment }
            .reduce(.zero) { $0 + Money(minorUnits: max(0, -$1.amount.minorUnits)) }
        let netCashChange = entries.reduce(.zero) { $0 + $1.amount }

        return DailyFinanceSummary(
            day: state.day,
            entries: entries,
            openingCash: state.cash - netCashChange,
            operatingIncome: operatingIncome,
            operatingExpense: operatingExpense,
            operatingResult: operatingIncome - operatingExpense,
            newLoanProceeds: newLoanProceeds,
            loanPayments: loanPayments,
            netCashChange: netCashChange,
            closingCash: state.cash
        )
    }

    private static func isFinancing(_ category: FinanceCategory) -> Bool {
        category == .loanProceeds || category == .loanPayment || category == .support
    }
}
