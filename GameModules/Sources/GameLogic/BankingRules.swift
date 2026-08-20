import GameDomain

public enum BankingRules {
    public static let crisisThreshold = Money(minorUnits: 10_000_000)
    public static let restructuringInstallmentCount = 24
    public static let restructuringIntervalMinutes = 7 * 1_440

    public static func creditLimit(for state: GameState) -> Money {
        let shopContribution = Int64(max(0, state.shopLevel - 1)) * 10_000_000
        let ratingContribution = Int64(max(0, state.ratingTenths - 30)) * 250_000
        return Money(minorUnits: 12_000_000 + shopContribution + ratingContribution)
    }

    public static func availableCredit(for state: GameState) -> Money {
        guard totalOverdue(for: state) == .zero else { return .zero }
        let activePrincipal = state.loans.reduce(Money.zero) { $0 + $1.remainingBalance }
        return max(.zero, creditLimit(for: state) - activePrincipal)
    }

    public static func totalOverdue(for state: GameState) -> Money {
        state.loans.reduce(.zero) { $0 + $1.overdueBalance }
    }

    public static func totalRepayment(for amount: Money, plan: LoanPlan) -> Money {
        Money(minorUnits: amount.minorUnits * Int64(10_000 + plan.interestBasisPoints) / 10_000)
    }

    public static func installmentAmount(for amount: Money, plan: LoanPlan) -> Money {
        let total = totalRepayment(for: amount, plan: plan).minorUnits
        let count = Int64(plan.installmentCount)
        return Money(minorUnits: (total + count - 1) / count)
    }

    public static func restructuredInstallment(for remainingBalance: Money) -> Money {
        let count = Int64(restructuringInstallmentCount)
        return Money(minorUnits: (remainingBalance.minorUnits + count - 1) / count)
    }
}
