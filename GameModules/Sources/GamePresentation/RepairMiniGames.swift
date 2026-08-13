import GameDomain
import SwiftUI

struct RepairMiniGameHost: View {
    let kind: RepairGameKind
    let partName: String
    let onComplete: (Int) -> Void

    var body: some View {
        Group {
            switch kind {
            case .gauge:
                GaugeMiniGame(partName: partName, onComplete: onComplete)
            case .bolts:
                BoltsMiniGame(partName: partName, onComplete: onComplete)
            case .wiring:
                WiringMiniGame(partName: partName, onComplete: onComplete)
            case .alignment:
                AlignmentMiniGame(partName: partName, onComplete: onComplete)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

private struct MiniGameShell<Content: View>: View {
    let title: String
    let instruction: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 20) {
            Capsule()
                .fill(GarageStyle.orange)
                .frame(width: 54, height: 6)
            Text(title)
                .font(.title2.bold())
            Text(instruction)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            content
            Spacer(minLength: 0)
        }
        .padding(24)
    }
}

private struct GaugeMiniGame: View {
    let partName: String
    let onComplete: (Int) -> Void
    @State private var start = Date()

    var body: some View {
        MiniGameShell(title: "Ayarı Yakala", instruction: "\(partName.capitalized) için ibre yeşil alandayken durdur.") {
            TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                let value = gaugeValue(at: context.date)
                ZStack(alignment: .leading) {
                    Capsule().fill(.gray.opacity(0.25)).frame(height: 34)
                    Capsule().fill(GarageStyle.mint.opacity(0.8))
                        .frame(width: 64, height: 34)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Circle().fill(GarageStyle.orange)
                        .frame(width: 28, height: 28)
                        .offset(x: value * 252)
                }
                .frame(width: 280)
                .accessibilityLabel("Hareketli ayar göstergesi")

                Button("Şimdi Durdur") {
                    let distance = abs(value - 0.5)
                    onComplete(max(20, Int(100 - distance * 180)))
                }
                .buttonStyle(ActionButtonStyle(tint: GarageStyle.mint))
            }
        }
    }

    private func gaugeValue(at date: Date) -> CGFloat {
        let elapsed = date.timeIntervalSince(start)
        return CGFloat((sin(elapsed * 3.1) + 1) / 2)
    }
}

private struct BoltsMiniGame: View {
    let partName: String
    let onComplete: (Int) -> Void
    @State private var nextBolt = 1
    @State private var mistakes = 0

    var body: some View {
        MiniGameShell(title: "Çapraz Sık", instruction: "\(partName.capitalized) civatalarını 1'den 4'e çapraz sırayla sık.") {
            LazyVGrid(columns: [.init(), .init()], spacing: 22) {
                ForEach([1, 3, 4, 2], id: \.self) { bolt in
                    Button {
                        tap(bolt)
                    } label: {
                        ZStack {
                            Circle().fill(bolt < nextBolt ? GarageStyle.mint : GarageStyle.raised)
                            Image(systemName: "screwdriver.fill")
                                .rotationEffect(.degrees(Double(bolt * 35)))
                                .font(.title)
                            Text("\(bolt)")
                                .font(.caption.bold())
                                .offset(y: 30)
                        }
                        .frame(width: 78, height: 78)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(bolt) numaralı civata")
                }
            }
            Text("Sıradaki: \(min(nextBolt, 4)) • Hata: \(mistakes)")
                .font(.headline.monospacedDigit())
        }
    }

    private func tap(_ bolt: Int) {
        guard bolt == nextBolt else {
            mistakes += 1
            return
        }
        if nextBolt == 4 {
            onComplete(max(25, 100 - mistakes * 18))
        } else {
            nextBolt += 1
        }
    }
}

private struct WiringMiniGame: View {
    let partName: String
    let onComplete: (Int) -> Void
    @State private var mistakes = 0

    var body: some View {
        MiniGameShell(title: "Doğru Hattı Bul", instruction: "\(partName.capitalized) için turuncu kabloyu aynı işaretli sokete bağla.") {
            HStack(spacing: 10) {
                Circle().fill(GarageStyle.orange).frame(width: 54, height: 54)
                Rectangle().fill(GarageStyle.orange).frame(height: 7)
                Image(systemName: "arrow.right")
            }
            .accessibilityLabel("Turuncu üçgen işaretli kaynak kablo")

            HStack(spacing: 18) {
                socket(color: .blue, symbol: "circle", correct: false)
                socket(color: GarageStyle.orange, symbol: "triangle", correct: true)
                socket(color: .purple, symbol: "square", correct: false)
            }
            Text("Yanlış bağlantı: \(mistakes)")
                .font(.headline.monospacedDigit())
        }
    }

    private func socket(color: Color, symbol: String, correct: Bool) -> some View {
        Button {
            if correct { onComplete(max(30, 100 - mistakes * 22)) }
            else { mistakes += 1 }
        } label: {
            VStack {
                RoundedRectangle(cornerRadius: 12).fill(color).frame(width: 70, height: 70)
                Image(systemName: "\(symbol).fill")
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(color.description) \(symbol) soket")
    }
}

private struct AlignmentMiniGame: View {
    let partName: String
    let onComplete: (Int) -> Void
    @State private var horizontal = 0.18
    @State private var vertical = 0.82

    var body: some View {
        MiniGameShell(title: "Hizala", instruction: "\(partName.capitalized) yatay ve dikey ayarlarını merkeze getir.") {
            VStack(spacing: 24) {
                VStack(alignment: .leading) {
                    Text("Yatay")
                    Slider(value: $horizontal, in: 0...1)
                        .tint(abs(horizontal - 0.5) < 0.08 ? GarageStyle.mint : GarageStyle.orange)
                }
                VStack(alignment: .leading) {
                    Text("Dikey")
                    Slider(value: $vertical, in: 0...1)
                        .tint(abs(vertical - 0.5) < 0.08 ? GarageStyle.mint : GarageStyle.orange)
                }
            }

            Button("Hizalamayı Tamamla") {
                let error = abs(horizontal - 0.5) + abs(vertical - 0.5)
                onComplete(max(20, Int(100 - error * 130)))
            }
            .buttonStyle(ActionButtonStyle(tint: GarageStyle.mint))
        }
    }
}
