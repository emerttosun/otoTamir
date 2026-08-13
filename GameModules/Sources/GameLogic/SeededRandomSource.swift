import Foundation
import GameDomain

public struct SeededRandomSource: RandomSource, Sendable {
    public private(set) var state: UInt64

    public init(seed: UInt64) {
        state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    public mutating func next(upperBound: Int) -> Int {
        precondition(upperBound > 0)
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Int((state >> 32) % UInt64(upperBound))
    }

    mutating func nextUUID() -> UUID {
        let parts = (0..<16).map { _ in UInt8(next(upperBound: 256)) }
        return UUID(uuid: (
            parts[0], parts[1], parts[2], parts[3],
            parts[4], parts[5], parts[6], parts[7],
            parts[8], parts[9], parts[10], parts[11],
            parts[12], parts[13], parts[14], parts[15]
        ))
    }
}

