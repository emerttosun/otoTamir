import GameDomain
import SwiftUI

struct FluidFillMiniGame: View {
    let partName: String
    let variant: Int
    let onComplete: (Int) -> Void
    @State private var level = 0.12
    @State private var pours = 0

    var body: some View {
        MiniGameShell(
            title: "Seviyeyi Tamamla",
            instruction: "\(partName.capitalized) haznesini MIN ile MAX arasındaki hedef çizgiye kadar doldur. Fazlasını geri alamazsın."
        ) {
            HStack(alignment: .bottom, spacing: 24) {
                GeometryReader { geometry in
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(.white.opacity(0.45), lineWidth: 4)
                        RoundedRectangle(cornerRadius: 14)
                            .fill(level > maximum ? GarageStyle.danger : GarageStyle.mint)
                            .frame(height: geometry.size.height * level)
                        marker("MAX", value: maximum, color: .white, size: geometry.size)
                        marker("HEDEF", value: target, color: GarageStyle.orange, size: geometry.size)
                        marker("MIN", value: minimum, color: .white, size: geometry.size)
                    }
                }
                .frame(width: 145, height: 250)
                .accessibilityLabel("Sıvı seviyesi yüzde \(Int(level * 100))")

                VStack(spacing: 12) {
                    Button {
                        level = min(1.0, level + pourAmount)
                        pours += 1
                    } label: {
                        Label("Vanayı Aç", systemImage: "drop.fill")
                    }
                    .buttonStyle(ActionButtonStyle(tint: GarageStyle.orange))
                    Text("Dolum: %\(Int(level * 100))")
                        .font(.headline.monospacedDigit())
                    Button("Dolumu Bitir") {
                        let distance = abs(level - target)
                        let overflowPenalty = level > maximum ? 25 : 0
                        onComplete(max(20, Int(100 - distance * 170) - overflowPenalty))
                    }
                    .buttonStyle(ActionButtonStyle(tint: GarageStyle.mint))
                }
            }
        }
    }

    private var minimum: Double { 0.42 }
    private var maximum: Double { 0.86 }
    private var target: Double { Double(56 + variant % 24) / 100 }
    private var pourAmount: Double { Double(5 + (variant + pours * 3) % 7) / 100 }

    private func marker(_ title: String, value: Double, color: Color, size: CGSize) -> some View {
        HStack(spacing: 4) {
            Rectangle().fill(color).frame(height: 2)
            Text(title).font(.system(size: 8, weight: .black)).foregroundStyle(color)
        }
        .frame(width: size.width - 12)
        .position(x: size.width / 2, y: size.height * (1 - value))
    }
}

struct TimingMiniGame: View {
    let partName: String
    let variant: Int
    let onComplete: (Int) -> Void
    @State private var positions = [0, 0, 0]

    var body: some View {
        MiniGameShell(
            title: "İşaretleri Eşleştir",
            instruction: "\(partName.capitalized) için üç kasnağı çevir; beyaz işaretleri verilen dereceye getir."
        ) {
            HStack(spacing: 15) {
                ForEach(0..<3, id: \.self) { index in
                    Button {
                        positions[index] = (positions[index] + 1) % 8
                    } label: {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle().stroke(GarageStyle.orange, lineWidth: 9)
                                Rectangle().fill(.white)
                                    .frame(width: 4, height: 30)
                                    .offset(y: -20)
                                    .rotationEffect(.degrees(Double(positions[index] * 45)))
                                Circle().fill(GarageStyle.raised).frame(width: 24, height: 24)
                            }
                            .frame(width: 82, height: 82)
                            Text("\(positions[index] * 45)° / \(targets[index] * 45)°")
                                .font(.caption2.bold().monospacedDigit())
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(index + 1). kasnak, mevcut \(positions[index] * 45) derece, hedef \(targets[index] * 45) derece")
                }
            }

            Button("Zamanlamayı Kilitle") {
                let totalSteps = zip(positions, targets).reduce(0) { result, pair in
                    let direct = abs(pair.0 - pair.1)
                    return result + min(direct, 8 - direct)
                }
                onComplete(max(20, 100 - totalSteps * 14))
            }
            .buttonStyle(ActionButtonStyle(tint: GarageStyle.mint))
        }
    }

    private var targets: [Int] {
        [1 + variant % 7, 1 + (variant / 3) % 7, 1 + (variant / 11) % 7]
    }
}

