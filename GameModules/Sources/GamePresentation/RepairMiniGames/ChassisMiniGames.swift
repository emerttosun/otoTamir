import GameDomain
import SwiftUI

struct BrakePadMiniGame: View {
    let onComplete: (Int) -> Void
    @State private var step = 0
    @State private var mistakes = 0

    var body: some View {
        MiniGameShell(
            title: "Fren Balatasını Değiştir",
            instruction: "Kaliperi güvenli sırayla aç, pistonu geri al, iki balatayı yerleştir ve pedalı sertleştir."
        ) {
            ZStack {
                Circle().stroke(.gray, lineWidth: 20).frame(width: 190, height: 190)
                Circle().stroke(.white.opacity(0.5), lineWidth: 5).frame(width: 95, height: 95)
                RoundedRectangle(cornerRadius: 8).fill(GarageStyle.orange).frame(width: 48, height: 100).offset(x: 75)
            }
            ForEach(Array(actions.enumerated()), id: \.offset) { index, action in
                Button {
                    if index == step {
                        step += 1
                        if step == actions.count { onComplete(max(25, 100 - mistakes * 14)) }
                    } else { mistakes += 1 }
                } label: {
                    HStack {
                        Image(systemName: index < step ? "checkmark.circle.fill" : "circle")
                        Text(action)
                        Spacer()
                        Text("\(index + 1)").font(.caption.bold())
                    }
                }
                .buttonStyle(ActionButtonStyle(tint: index == step ? GarageStyle.orange : GarageStyle.raised, foreground: .white))
                .disabled(index < step)
            }
        }
    }

    private let actions = ["Kaliper pimlerini sök", "Pistonu geri al", "İç balatayı yerleştir", "Dış balatayı yerleştir", "Kaliperi kapat", "Fren pedalını pompala"]
}

struct ToeAdjustmentMiniGame: View {
    let variant: Int
    let onComplete: (Int) -> Void
    @State private var left = -2.4
    @State private var right = 2.1

    var body: some View {
        MiniGameShell(
            title: "Rot Ayarını Eşitle",
            instruction: "Sol ve sağ rot kollarını çevir; iki tekeri de hedef toe değerine getir."
        ) {
            HStack(spacing: 55) {
                wheel(angle: left)
                wheel(angle: right)
            }
            valueSlider("Sol teker", value: $left)
            valueSlider("Sağ teker", value: $right)
            Text(String(format: "Hedef: %.1f° • toplam fark %.1f°", target, abs(left - target) + abs(right - target)))
                .font(.headline.monospacedDigit())
            Button("Kontra Somunlarını Kilitle") {
                let error = abs(left - target) + abs(right - target)
                onComplete(max(20, 100 - Int(error * 24)))
            }.buttonStyle(ActionButtonStyle(tint: GarageStyle.mint))
        }
    }

    private func wheel(angle: Double) -> some View {
        RoundedRectangle(cornerRadius: 18).fill(.gray).frame(width: 70, height: 135)
            .rotationEffect(.degrees(angle * 5))
    }

    private func valueSlider(_ title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading) {
            Text("\(title): \(String(format: "%.1f°", value.wrappedValue))").font(.caption.bold())
            Slider(value: value, in: -3...3, step: 0.1).tint(GarageStyle.orange)
        }
    }

    private var target: Double { Double((variant % 9) - 4) / 10 }
}

struct ClutchCenteringMiniGame: View {
    let variant: Int
    let onComplete: (Int) -> Void
    @State private var x = 35.0
    @State private var y = -28.0
    @State private var moves = 0

    var body: some View {
        MiniGameShell(
            title: "Debriyaj Diskini Merkezle",
            instruction: "Diski baskının merkezine getir; merkezleme mili zorlanmadan geçince baskıyı sabitle."
        ) {
            ZStack {
                Circle().stroke(.white.opacity(0.3), lineWidth: 28).frame(width: 230, height: 230)
                Circle().fill(GarageStyle.orange.opacity(0.75)).frame(width: 115, height: 115)
                    .offset(x: x, y: y)
                Circle().stroke(.white, lineWidth: 5).frame(width: 34, height: 34)
            }
            HStack {
                Button { adjust(dx: -8, dy: 0) } label: { Image(systemName: "arrow.left") }
                Button { adjust(dx: 0, dy: -8) } label: { Image(systemName: "arrow.up") }
                Button { adjust(dx: 0, dy: 8) } label: { Image(systemName: "arrow.down") }
                Button { adjust(dx: 8, dy: 0) } label: { Image(systemName: "arrow.right") }
            }.buttonStyle(ActionButtonStyle(tint: GarageStyle.raised, foreground: .white))
            Button("Merkezleme Milini Tak") {
                let error = hypot(x, y)
                onComplete(max(20, 100 - Int(error * 2) - max(0, moves - 12)))
            }.buttonStyle(ActionButtonStyle(tint: GarageStyle.mint))
        }
        .onAppear {
            x = Double(20 + variant % 22)
            y = -Double(16 + (variant / 3) % 20)
        }
    }

    private func adjust(dx: Double, dy: Double) {
        x += dx; y += dy; moves += 1
    }
}

