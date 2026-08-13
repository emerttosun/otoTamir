import Foundation

public struct Money: Codable, Hashable, Comparable, Sendable {
    public let minorUnits: Int64

    public init(minorUnits: Int64) {
        self.minorUnits = minorUnits
    }

    public static let zero = Money(minorUnits: 0)

    public static func < (lhs: Money, rhs: Money) -> Bool {
        lhs.minorUnits < rhs.minorUnits
    }

    public static func + (lhs: Money, rhs: Money) -> Money {
        Money(minorUnits: lhs.minorUnits + rhs.minorUnits)
    }

    public static func - (lhs: Money, rhs: Money) -> Money {
        Money(minorUnits: lhs.minorUnits - rhs.minorUnits)
    }

    public static func * (lhs: Money, rhs: Int) -> Money {
        Money(minorUnits: lhs.minorUnits * Int64(rhs))
    }

    public var liraText: String {
        let value = Decimal(minorUnits) / 100
        return value.formatted(.currency(code: "TRY").locale(Locale(identifier: "tr_TR")))
    }
}

