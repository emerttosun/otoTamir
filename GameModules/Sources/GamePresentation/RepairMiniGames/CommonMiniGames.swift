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
    @State private var toolRotation = 0.0
    @State private var feedbackTrigger = 0

    var body: some View {
        MiniGameShell(
            title: "Bijonları Çapraz Sık",
            instruction: "Darbeli somun sıkmayı sıradaki bijona dokundur. Dört bijonu çapraz sırayla sık."
        ) {
            ZStack {
                Circle()
                    .fill(Color.black.gradient)
                    .overlay(Circle().stroke(Color.white.opacity(0.16), lineWidth: 7))

                Circle()
                    .fill(Color.gray.opacity(0.34))
                    .frame(width: 174, height: 174)
                    .overlay(Circle().stroke(Color.white.opacity(0.24), lineWidth: 3))

                ForEach(0..<8, id: \.self) { spoke in
                    Capsule()
                        .fill(Color.white.opacity(0.28))
                        .frame(width: 13, height: 70)
                        .offset(y: -37)
                        .rotationEffect(.degrees(Double(spoke) * 45))
                }

                Circle()
                    .fill(GarageStyle.raised)
                    .frame(width: 82, height: 82)
                    .overlay(Circle().stroke(Color.white.opacity(0.22), lineWidth: 2))

                ForEach(1...4, id: \.self) { bolt in
                    boltButton(bolt)
                }

                Circle()
                    .fill(Color.black.opacity(0.75))
                    .frame(width: 22, height: 22)
            }
            .frame(width: 250, height: 250)
            .accessibilityElement(children: .contain)

            HStack(spacing: 10) {
                Image(systemName: "wrench.adjustable.fill")
                    .font(.title2)
                    .foregroundStyle(GarageStyle.orange)
                    .rotationEffect(.degrees(toolRotation))
                Text("Sıradaki bijon: \(sequence[min(currentIndex, sequence.count - 1)]) • Hata: \(mistakes)")
            }
                .font(.headline.monospacedDigit())
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: feedbackTrigger)
    }

    private func boltButton(_ bolt: Int) -> some View {
        let isCompleted = completed.contains(bolt)
        let isNext = bolt == sequence[min(currentIndex, sequence.count - 1)]

        return Button {
            tap(bolt)
        } label: {
            ZStack {
                Circle()
                    .fill(isCompleted ? GarageStyle.mint : (isNext ? GarageStyle.orange : GarageStyle.raised))
                Image(systemName: isCompleted ? "checkmark" : "hexagon.fill")
                    .font(.headline.bold())
                    .foregroundStyle(isCompleted ? Color.black : Color.white)
                Text("\(bolt)")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .offset(y: 29)
            }
            .frame(width: 52, height: 52)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .offset(boltOffset(bolt))
        .accessibilityLabel("\(bolt) numaralı bijon")
        .accessibilityHint(isNext ? "Sıradaki bijon" : "Çapraz sıkma sırasını takip et")
    }

    private func tap(_ bolt: Int) {
        guard bolt == sequence[currentIndex] else {
            mistakes += 1
            return
        }
        withAnimation(.snappy(duration: 0.22)) {
            completed.insert(bolt)
            toolRotation += 45
        }
        feedbackTrigger += 1
        if currentIndex == sequence.count - 1 {
            onComplete(max(25, 100 - mistakes * 18))
        } else {
            currentIndex += 1
        }
    }

    private func boltOffset(_ bolt: Int) -> CGSize {
        switch bolt {
        case 1: CGSize(width: 0, height: -42)
        case 2: CGSize(width: 42, height: 0)
        case 3: CGSize(width: 0, height: 42)
        default: CGSize(width: -42, height: 0)
        }
    }

    private var sequence: [Int] {
        [[1, 3, 2, 4], [2, 4, 1, 3], [3, 1, 4, 2], [4, 2, 3, 1]][variant % 4]
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
