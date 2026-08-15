import GameDomain
import SwiftUI

struct BumperClipMiniGame: View {
    let variant: Int
    let onComplete: (Int) -> Void
    @State private var installed: Set<Int> = []
    @State private var mistakes = 0

    var body: some View {
        MiniGameShell(
            title: "Tampon Klipslerini Oturt",
            instruction: "Tamponu köşeden zorlamadan ortadan dışa doğru klipslerine bastır."
        ) {
            RoundedRectangle(cornerRadius: 45).stroke(GarageStyle.orange, lineWidth: 18)
                .frame(width: 280, height: 105)
            HStack(spacing: 15) {
                ForEach(0..<7, id: \.self) { clip in
                    Button {
                        let expected = sequence[installed.count]
                        if clip == expected {
                            installed.insert(clip)
                            if installed.count == 7 { onComplete(max(25, 100 - mistakes * 12)) }
                        } else { mistakes += 1 }
                    } label: {
                        Image(systemName: installed.contains(clip) ? "checkmark.circle.fill" : "circle.dotted")
                            .font(.title2).foregroundStyle(installed.contains(clip) ? GarageStyle.mint : .white)
                    }.buttonStyle(.plain)
                }
            }
            Text("Oturan klips \(installed.count)/7 • zorlama \(mistakes)").font(.headline.monospacedDigit())
        }
    }

    private var sequence: [Int] {
        variant.isMultiple(of: 2) ? [3, 2, 4, 1, 5, 0, 6] : [3, 4, 2, 5, 1, 6, 0]
    }
}

struct DoorGapMiniGame: View {
    let variant: Int
    let onComplete: (Int) -> Void
    @State private var upper = 1.0
    @State private var lower = 7.0

    var body: some View {
        MiniGameShell(
            title: "Kapı Aralığını Ayarla",
            instruction: "Menteşe yüksekliğini ayarla; üst ve alt kapı aralığı eşit olsun, kilit karşılığına sürtmesin."
        ) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 10).fill(.gray).frame(width: 115, height: 210)
                VStack {
                    Spacer().frame(height: CGFloat(upper * 8))
                    RoundedRectangle(cornerRadius: 10).stroke(GarageStyle.orange, lineWidth: 5).frame(width: 115, height: 190)
                    Spacer().frame(height: CGFloat(lower * 8))
                }.frame(height: 250)
            }
            gapSlider("Üst aralık", value: $upper)
            gapSlider("Alt aralık", value: $lower)
            Button("Menteşe ve Kilidi Sabitle") {
                let error = abs(upper - target) + abs(lower - target)
                onComplete(max(20, 100 - Int(error * 16)))
            }.buttonStyle(ActionButtonStyle(tint: GarageStyle.mint))
        }
    }

    private func gapSlider(_ title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading) {
            Text("\(title): \(String(format: "%.1f mm", value.wrappedValue))").font(.caption.bold())
            Slider(value: value, in: 1...8, step: 0.5).tint(GarageStyle.orange)
        }
    }

    private var target: Double { Double(6 + variant % 5) / 2 }
}

struct DentPullMiniGame: View {
    let variant: Int
    let onComplete: (Int) -> Void
    @State private var step = 0
    @State private var mistakes = 0
    @State private var raised: Set<Int> = []

    var body: some View {
        MiniGameShell(
            title: "Göçüğü Dıştan İçe Topla",
            instruction: "Sacın tepesine birden yüklenme. Gerginliği çevreden merkeze doğru küçük çekişlerle dağıt."
        ) {
            GeometryReader { geometry in
                ZStack {
                    RoundedRectangle(cornerRadius: 34)
                        .fill(
                            LinearGradient(
                                colors: [Color.gray.opacity(0.72), Color.gray.opacity(0.38)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 34)
                                .stroke(Color.white.opacity(0.28), lineWidth: 2)
                        }

                    Ellipse()
                        .fill(Color.black.opacity(0.3))
                        .frame(width: geometry.size.width * 0.46, height: geometry.size.height * 0.42)
                        .overlay {
                            Ellipse()
                                .stroke(GarageStyle.danger.opacity(0.72), lineWidth: 4)
                        }
                        .shadow(color: .black.opacity(0.6), radius: 18)

                    ForEach(0..<9, id: \.self) { point in
                        pullPoint(point, in: geometry.size)
                    }

                    VStack {
                        HStack {
                            Label("Çamurluk sacı", systemImage: "car.side")
                                .font(.caption.bold())
                                .foregroundStyle(.white.opacity(0.9))
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(16)
                }
            }
            .frame(height: 300)
            Text("Çekiş \(step)/9 • iz riski \(mistakes)").font(.headline.monospacedDigit())
        }
    }

    private func pullPoint(_ point: Int, in size: CGSize) -> some View {
        let position = positions[point]
        return Button {
            guard step < sequence.count else { return }
            if point == sequence[step] {
                raised.insert(point)
                step += 1
                if step == sequence.count { onComplete(max(25, 100 - mistakes * 11)) }
            } else {
                mistakes += 1
            }
        } label: {
            Circle()
                .fill(raised.contains(point) ? GarageStyle.mint : depthColor(point))
                .frame(width: point == 4 ? 58 : 48, height: point == 4 ? 58 : 48)
                .overlay {
                    Image(systemName: raised.contains(point) ? "checkmark" : "arrow.up")
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                }
                .overlay {
                    Circle().stroke(.white.opacity(0.75), lineWidth: 2)
                }
        }
        .buttonStyle(.plain)
        .position(x: size.width * position.x, y: size.height * position.y)
        .accessibilityLabel("Çekme noktası \(point + 1)")
    }

    private var sequence: [Int] {
        let clockwise = [0, 2, 8, 6, 1, 5, 7, 3, 4]
        return variant.isMultiple(of: 2) ? clockwise : [2, 0, 6, 8, 5, 7, 3, 1, 4]
    }

    private var positions: [CGPoint] {
        [
            CGPoint(x: 0.2, y: 0.25), CGPoint(x: 0.5, y: 0.17), CGPoint(x: 0.8, y: 0.25),
            CGPoint(x: 0.15, y: 0.52), CGPoint(x: 0.5, y: 0.52), CGPoint(x: 0.85, y: 0.52),
            CGPoint(x: 0.2, y: 0.79), CGPoint(x: 0.5, y: 0.87), CGPoint(x: 0.8, y: 0.79)
        ]
    }

    private func depthColor(_ point: Int) -> Color {
        point == 4 ? GarageStyle.danger : GarageStyle.orange.opacity(point.isMultiple(of: 2) ? 0.65 : 0.4)
    }
}

