import GameDomain
import SwiftUI

struct RepairMiniGameHost: View {
    let kind: RepairGameKind
    let partName: String
    let challengeKey: String
    let onComplete: (Int) -> Void

    private var variant: Int {
        challengeKey.unicodeScalars.reduce(17) { ($0 &* 31 &+ Int($1.value)) % 10_007 }
    }

    var body: some View {
        Group {
            switch kind {
            case .gauge:
                GaugeMiniGame(partName: partName, variant: variant, onComplete: onComplete)
            case .bolts:
                BoltsMiniGame(partName: partName, variant: variant, onComplete: onComplete)
            case .wiring:
                WiringMiniGame(partName: partName, variant: variant, onComplete: onComplete)
            case .alignment:
                AlignmentMiniGame(partName: partName, variant: variant, onComplete: onComplete)
            case .fluidFill:
                FluidFillMiniGame(partName: partName, variant: variant, onComplete: onComplete)
            case .timing:
                TimingMiniGame(partName: partName, variant: variant, onComplete: onComplete)
            case .beltTension:
                BeltTensionMiniGame(variant: variant, onComplete: onComplete)
            case .coolantBleed:
                CoolantBleedMiniGame(variant: variant, onComplete: onComplete)
            case .headGasketTorque:
                HeadGasketTorqueMiniGame(variant: variant, onComplete: onComplete)
            case .batteryTerminals:
                BatteryTerminalMiniGame(onComplete: onComplete)
            case .chargingVoltage:
                ChargingVoltageMiniGame(variant: variant, onComplete: onComplete)
            case .sensorGap:
                SensorGapMiniGame(variant: variant, onComplete: onComplete)
            case .brakePads:
                BrakePadMiniGame(onComplete: onComplete)
            case .toeAdjustment:
                ToeAdjustmentMiniGame(variant: variant, onComplete: onComplete)
            case .clutchCentering:
                ClutchCenteringMiniGame(variant: variant, onComplete: onComplete)
            case .bumperClips:
                BumperClipMiniGame(variant: variant, onComplete: onComplete)
            case .doorGap:
                DoorGapMiniGame(variant: variant, onComplete: onComplete)
            case .dentPull:
                DentPullMiniGame(variant: variant, onComplete: onComplete)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
