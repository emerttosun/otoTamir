import GameDomain
import SwiftUI

struct MiniGameShell<Content: View>: View {
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
                .fixedSize(horizontal: false, vertical: true)
            content
            Spacer(minLength: 0)
        }
        .padding(24)
    }
}

struct GaugeMiniGame: View {
    let partName: String
    let variant: Int
    let onComplete: (Int) -> Void
    @State private var start = Date()

    var body: some View {
        MiniGameShell(title: "Ayarı Yakala", instruction: "\(partName.capitalized) için ibre yeşil alandayken durdur.") {
            TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                let value = gaugeValue(at: context.date)
                let target = targetValue
                ZStack(alignment: .leading) {
                    Capsule().fill(.gray.opacity(0.25)).frame(width: 280, height: 34)
                    Capsule().fill(GarageStyle.mint.opacity(0.8))
                        .frame(width: 54, height: 34)
                        .offset(x: target * 226)
                    Circle().fill(GarageStyle.orange)
                        .frame(width: 28, height: 28)
                        .offset(x: value * 252)
                }
                .frame(width: 280)
                .accessibilityLabel("Hareketli ayar göstergesi")

                Button("Şimdi Durdur") {
                    let distance = abs(value - targetValue)
                    onComplete(max(20, Int(100 - distance * 180)))
                }
                .buttonStyle(ActionButtonStyle(tint: GarageStyle.mint))
            }
        }
    }

    private var targetValue: CGFloat { CGFloat(22 + variant % 57) / 100 }

    private func gaugeValue(at date: Date) -> CGFloat {
        let elapsed = date.timeIntervalSince(start)
        return CGFloat((sin(elapsed * 3.1) + 1) / 2)
    }
}

struct BoltsMiniGame: View {
    let partName: String
    let variant: Int
    let onComplete: (Int) -> Void
    @State private var currentIndex = 0
    @State private var mistakes = 0

    @State private var completed: Set<Int> = []

    var body: some View {
        MiniGameShell(title: "Çapraz Sık", instruction: "\(partName.capitalized) civatalarını 1'den 4'e çapraz sırayla sık.") {
            LazyVGrid(columns: [.init(), .init()], spacing: 22) {
                ForEach([1, 3, 4, 2], id: \.self) { bolt in
                    Button {
                        tap(bolt)
                    } label: {
                        ZStack {
                            Circle().fill(completed.contains(bolt) ? GarageStyle.mint : GarageStyle.raised)
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
            Text("Sıradaki: \(sequence[min(currentIndex, sequence.count - 1)]) • Hata: \(mistakes)")
                .font(.headline.monospacedDigit())
        }
    }

    private func tap(_ bolt: Int) {
        guard bolt == sequence[currentIndex] else {
            mistakes += 1
            return
        }
        completed.insert(bolt)
        if currentIndex == sequence.count - 1 {
            onComplete(max(25, 100 - mistakes * 18))
        } else {
            currentIndex += 1
        }
    }

    private var sequence: [Int] {
        [[1, 2, 3, 4], [1, 3, 2, 4], [2, 4, 1, 3], [3, 1, 4, 2]][variant % 4]
    }
}

struct WiringMiniGame: View {
    let partName: String
    let variant: Int
    let onComplete: (Int) -> Void
    @State private var mistakes = 0

    var body: some View {
        MiniGameShell(title: "Doğru Hattı Bul", instruction: "\(partName.capitalized) için \(sourceName) kabloyu aynı renkli sokete bağla.") {
            HStack(spacing: 10) {
                Circle().fill(sourceColor).frame(width: 54, height: 54)
                Rectangle().fill(sourceColor).frame(height: 7)
                Image(systemName: "arrow.right")
            }
            .accessibilityLabel("\(sourceName) kaynak kablo")

            HStack(spacing: 18) {
                socket(color: .blue, symbol: "circle", correct: correctIndex == 0)
                socket(color: GarageStyle.orange, symbol: "triangle", correct: correctIndex == 1)
                socket(color: .purple, symbol: "square", correct: correctIndex == 2)
            }
            Text("Yanlış bağlantı: \(mistakes)")
                .font(.headline.monospacedDigit())
        }
    }

    private var correctIndex: Int { variant % 3 }
    private var sourceColor: Color { [.blue, GarageStyle.orange, .purple][correctIndex] }
    private var sourceName: String { ["mavi", "turuncu", "mor"][correctIndex] }

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

struct AlignmentMiniGame: View {
    let partName: String
    let variant: Int
    let onComplete: (Int) -> Void
    @State private var horizontal = 0.18
    @State private var vertical = 0.82

    var body: some View {
        MiniGameShell(title: "Hizala", instruction: "\(partName.capitalized) yatay ve dikey ayarlarını gösterilen ölçülere getir.") {
            VStack(spacing: 24) {
                VStack(alignment: .leading) {
                    Text("Yatay")
                    Slider(value: $horizontal, in: 0...1)
                        .tint(abs(horizontal - horizontalTarget) < 0.08 ? GarageStyle.mint : GarageStyle.orange)
                    Text("Hedef: %\(Int(horizontalTarget * 100))").font(.caption2).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading) {
                    Text("Dikey")
                    Slider(value: $vertical, in: 0...1)
                        .tint(abs(vertical - verticalTarget) < 0.08 ? GarageStyle.mint : GarageStyle.orange)
                    Text("Hedef: %\(Int(verticalTarget * 100))").font(.caption2).foregroundStyle(.secondary)
                }
            }

            Button("Hizalamayı Tamamla") {
                let error = abs(horizontal - horizontalTarget) + abs(vertical - verticalTarget)
                onComplete(max(20, Int(100 - error * 130)))
            }
            .buttonStyle(ActionButtonStyle(tint: GarageStyle.mint))
        }
    }

    private var horizontalTarget: Double { Double(25 + variant % 51) / 100 }
    private var verticalTarget: Double { Double(25 + (variant / 7) % 51) / 100 }
}
