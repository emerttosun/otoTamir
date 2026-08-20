import GameDomain

public enum BankingRules {
    public static func creditLimit(for state: GameState) -> Money {
        let shopContribution = Int64(max(0, state.shopLevel - 1)) * 10_000_000
        let ratingContribution = Int64(max(0, state.ratingTenths - 30)) * 250_000
        return Money(minorUnits: 12_000_000 + shopContribution + ratingContribution)
    }

    public static func availableCredit(for state: GameState) -> Money {
        let activePrincipal = state.loans.reduce(Money.zero) { $0 + $1.remainingBalance }
        return max(.zero, creditLimit(for: state) - activePrincipal)
    }

    public static func totalRepayment(for amount: Money, plan: LoanPlan) -> Money {
        Money(minorUnits: amount.minorUnits * Int64(10_000 + plan.interestBasisPoints) / 10_000)
    }

    public static func installmentAmount(for amount: Money, plan: LoanPlan) -> Money {
        let total = totalRepayment(for: amount, plan: plan).minorUnits
        let count = Int64(plan.installmentCount)
        return Money(minorUnits: (total + count - 1) / count)
    }
}
