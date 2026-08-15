import Foundation
import GameDomain

extension GameEngine {
    func supports(_ facility: ShopFacility) -> Bool {
        catalog.shopLevel(state.shopLevel)?.facilities.contains(facility) == true
    }

    mutating func recordFinance(amount: Money, category: FinanceCategory, note: String) {
        let ordinal = UInt64(state.financeEntries.count + 1)
        let dayValue = UInt32(max(0, state.day))
        let id = UUID(uuid: (
            0x46, 0x49, 0x4E, 0x41,
            UInt8((dayValue >> 24) & 0xFF), UInt8((dayValue >> 16) & 0xFF),
            UInt8((dayValue >> 8) & 0xFF), UInt8(dayValue & 0xFF),
            UInt8((ordinal >> 56) & 0xFF), UInt8((ordinal >> 48) & 0xFF),
            UInt8((ordinal >> 40) & 0xFF), UInt8((ordinal >> 32) & 0xFF),
            UInt8((ordinal >> 24) & 0xFF), UInt8((ordinal >> 16) & 0xFF),
            UInt8((ordinal >> 8) & 0xFF), UInt8(ordinal & 0xFF)
        ))
        state.financeEntries.append(FinanceEntry(
            id: id,
            day: state.day,
            category: category,
            amount: amount,
            note: note
        ))
    }

    mutating func recordIncident(
        kind: IncidentKind,
        message: String,
        cashImpact: Money = .zero,
        trustImpact: Int = 0,
        craftsmanshipImpact: Int = 0,
        suspicionImpact: Int = 0
    ) {
        let sequence = state.incidents.count + 1
        let value = UInt64(sequence)
        let id = UUID(uuid: (
            0x4F, 0x4C, 0x41, 0x59,
            0, 0, 0, 0,
            UInt8((value >> 56) & 0xFF), UInt8((value >> 48) & 0xFF),
            UInt8((value >> 40) & 0xFF), UInt8((value >> 32) & 0xFF),
            UInt8((value >> 24) & 0xFF), UInt8((value >> 16) & 0xFF),
            UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF)
        ))
        state.incidents.append(GameIncident(
            id: id,
            sequence: sequence,
            kind: kind,
            message: message,
            cashImpact: cashImpact,
            trustImpact: trustImpact,
            craftsmanshipImpact: craftsmanshipImpact,
            suspicionImpact: suspicionImpact
        ))
        if state.incidents.count > 60 {
            state.incidents.removeFirst(state.incidents.count - 60)
        }
    }

    func percent(_ money: Money, _ value: Int) -> Money {
        Money(minorUnits: money.minorUnits * Int64(value) / 100)
    }
}

extension Array {
    func shuffledDeterministically(using random: inout SeededRandomSource) -> [Element] {
        guard count > 1 else { return self }
        var result = self
        for index in stride(from: result.count - 1, through: 1, by: -1) {
            let other = random.next(upperBound: index + 1)
            if index != other { result.swapAt(index, other) }
        }
        return result
    }
}
