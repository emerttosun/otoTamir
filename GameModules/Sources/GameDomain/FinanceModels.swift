import Foundation

public enum FinanceCategory: String, Codable, Sendable {
    case customerIncome
    case vehicleSale
    case parts
    case partReturn
    case partReturnLoss
    case rent
    case utilities
    case supplies
    case wages
    case recruitment
    case wash
    case shopUpgrade
    case salvageVehicle
    case restoration
    case fine
    case support
    case loanProceeds
    case loanPayment
    case assetLiquidation
    case listingFee

    public var title: String {
        switch self {
        case .customerIncome: "Müşteri ödemesi"
        case .vehicleSale: "Araç satışı"
        case .parts: "Parça alımı"
        case .partReturn: "Parça iadesi"
        case .partReturnLoss: "Parça iade kesintisi"
        case .rent: "Dükkân kirası"
        case .utilities: "Elektrik, su ve enerji"
        case .supplies: "Sarf ve temizlik"
        case .wages: "Çırak ücreti"
        case .recruitment: "Çırak ilanı ve işe giriş"
        case .wash: "Araç yıkama"
        case .shopUpgrade: "Dükkân geliştirmesi"
        case .salvageVehicle: "Hasarlı araç alımı"
        case .restoration: "Restorasyon parçaları"
        case .fine: "Ceza ve iade"
        case .support: "Esnaf desteği"
        case .loanProceeds: "Banka kredisi"
        case .loanPayment: "Kredi taksiti"
        case .assetLiquidation: "Kriz varlık satışı"
        case .listingFee: "İlan ücreti"
        }
    }
}

public enum LoanPlan: String, Codable, CaseIterable, Sendable {
    case short
    case standard
    case flexible

    public var title: String {
        switch self {
        case .short: "Kısa Vade"
        case .standard: "Dengeli"
        case .flexible: "Esnek Vade"
        }
    }

    public var installmentCount: Int {
        switch self {
        case .short: 4
        case .standard: 8
        case .flexible: 12
        }
    }

    public var installmentIntervalDays: Int {
        switch self {
        case .short: 2
        case .standard: 3
        case .flexible: 4
        }
    }

    public var interestBasisPoints: Int {
        switch self {
        case .short: 800
        case .standard: 1500
        case .flexible: 2400
        }
    }

    public var interestText: String {
        let whole = interestBasisPoints / 100
        let fraction = interestBasisPoints % 100
        return fraction == 0 ? "%\(whole)" : "%\(whole),\(fraction)"
    }
}

public struct BankLoan: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let plan: LoanPlan
    public let borrowedAmount: Money
    public let totalRepayment: Money
    public var remainingBalance: Money
    public var remainingInstallments: Int
    public var installmentAmount: Money
    public var installmentIntervalMinutes: Int
    public var nextPaymentMinute: Int
    public var overdueBalance: Money
    public var isRestructured: Bool

    public init(
        id: UUID,
        plan: LoanPlan,
        borrowedAmount: Money,
        totalRepayment: Money,
        installmentAmount: Money,
        nextPaymentMinute: Int
    ) {
        self.id = id
        self.plan = plan
        self.borrowedAmount = borrowedAmount
        self.totalRepayment = totalRepayment
        remainingBalance = totalRepayment
        remainingInstallments = plan.installmentCount
        self.installmentAmount = installmentAmount
        installmentIntervalMinutes = plan.installmentIntervalDays * 1_440
        self.nextPaymentMinute = nextPaymentMinute
        overdueBalance = .zero
        isRestructured = false
    }

    private enum CodingKeys: String, CodingKey {
        case id, plan, borrowedAmount, totalRepayment, remainingBalance
        case remainingInstallments, installmentAmount, installmentIntervalMinutes
        case nextPaymentMinute, overdueBalance, isRestructured
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        plan = try values.decode(LoanPlan.self, forKey: .plan)
        borrowedAmount = try values.decode(Money.self, forKey: .borrowedAmount)
        totalRepayment = try values.decode(Money.self, forKey: .totalRepayment)
        remainingBalance = try values.decode(Money.self, forKey: .remainingBalance)
        remainingInstallments = try values.decode(Int.self, forKey: .remainingInstallments)
        installmentAmount = try values.decode(Money.self, forKey: .installmentAmount)
        installmentIntervalMinutes = try values.decode(Int.self, forKey: .installmentIntervalMinutes)
        nextPaymentMinute = try values.decode(Int.self, forKey: .nextPaymentMinute)
        overdueBalance = try values.decodeIfPresent(Money.self, forKey: .overdueBalance) ?? .zero
        isRestructured = try values.decodeIfPresent(Bool.self, forKey: .isRestructured) ?? false
    }
}

public struct FinanceEntry: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let day: Int
    public let category: FinanceCategory
    public let amount: Money
    public let note: String

    public init(id: UUID, day: Int, category: FinanceCategory, amount: Money, note: String) {
        self.id = id
        self.day = day
        self.category = category
        self.amount = amount
        self.note = note
    }
}

public struct ShopReview: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let customerID: String
    public let stars: Int
    public let text: String
    public let day: Int

    public init(id: UUID, customerID: String, stars: Int, text: String, day: Int) {
        self.id = id
        self.customerID = customerID
        self.stars = min(5, max(1, stars))
        self.text = text
        self.day = day
    }
}

public struct InventoryItem: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let jobID: UUID
    public let faultID: String
    public let partName: String
    public let quality: PartQuality
    public let purchasePrice: Money

    public init(
        id: UUID,
        jobID: UUID,
        faultID: String,
        partName: String,
        quality: PartQuality,
        purchasePrice: Money
    ) {
        self.id = id
        self.jobID = jobID
        self.faultID = faultID
        self.partName = partName
        self.quality = quality
        self.purchasePrice = purchasePrice
    }
}

public enum ConsequenceKind: String, Codable, Sendable {
    case complaint
    case comeback
    case inspection
    case referral
}

public struct ScheduledConsequence: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let dueDay: Int
    public let kind: ConsequenceKind
    public let amount: Money
    public let message: String

    public init(id: UUID, dueDay: Int, kind: ConsequenceKind, amount: Money, message: String) {
        self.id = id
        self.dueDay = dueDay
        self.kind = kind
        self.amount = amount
        self.message = message
    }
}
