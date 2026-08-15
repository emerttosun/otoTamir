import SwiftUI

struct BrakeDiscRunoutMiniGame: View {
    let variant: Int
    let onComplete: (Int) -> Void
    @State private var angle = 0.0
    @State private var correction = 0.0
    @State private var samples: [Double] = []

    var body: some View {
        MiniGameShell(title: "Disk Salgısını Ölç", instruction: "Komparatör takılıyken diski farklı açılarda çevir; en yüksek sapmayı bulup porya yüzeyi düzeltmesini ayarla.") {
            ZStack {
                Circle().fill(.gray.opacity(0.45)).frame(width: 210, height: 210)
                Circle().stroke(.white.opacity(0.5), lineWidth: 3).frame(width: 90, height: 90)
                Image(systemName: "arrowtriangle.down.fill").foregroundStyle(GarageStyle.orange).offset(y: -120)
            }.rotationEffect(.degrees(angle))
            Text("Komparatör: \(reading, specifier: "%.2f") mm").font(.headline.monospacedDigit())
            Slider(value: $angle, in: 0...330, step: 30).tint(GarageStyle.orange)
            Button("Bu Açıyı Ölç") { samples.append(reading) }
                .buttonStyle(ActionButtonStyle(tint: GarageStyle.raised, foreground: .white))
            Slider(value: $correction, in: -0.3...0.3, step: 0.01).tint(GarageStyle.mint)
                .accessibilityLabel("Porya yüzeyi düzeltmesi")
            Button("Düzeltmeyi Uygula") {
                let coveragePenalty = max(0, 4 - samples.count) * 10
                onComplete(max(20, 100 - Int(abs(correction - targetCorrection) * 190) - coveragePenalty))
            }.buttonStyle(ActionButtonStyle(tint: GarageStyle.mint))
        }
    }
    private var reading: Double { abs(sin(angle * .pi / 180)) * 0.28 + Double(variant % 5) / 100 }
    private var targetCorrection: Double { -Double(variant % 19 - 9) / 100 }
}

struct ShockCompressionMiniGame: View {
    let variant: Int
    let onComplete: (Int) -> Void
    @State private var compression = 0.0
    @State private var releases = 0
    @State private var stability = 0

    var body: some View {
        MiniGameShell(title: "Amortisörü Sıkıştır ve Test Et", instruction: "Yayı kontrollü sıkıştır, amortisörü tak ve geri dönüşün tek harekette sakinleştiğini doğrula.") {
            ZStack(alignment: .bottom) {
                Capsule().stroke(.gray, lineWidth: 9).frame(width: 95, height: 260)
                ForEach(0..<6, id: \.self) { turn in
                    Capsule().stroke(GarageStyle.orange, lineWidth: 7).frame(width: 130, height: 26)
                        .offset(y: -CGFloat(turn) * CGFloat(38 - compression / 6))
                }
            }.frame(height: 280)
            Text("Sıkıştırma %\(Int(compression)) • test \(releases)/3")
                .font(.headline.monospacedDigit())
            Slider(value: $compression, in: 0...100).tint(GarageStyle.orange)
            Button("Bırak ve Geri Dönüşü Ölç") {
                releases += 1
                stability += max(0, 100 - abs(Int(compression) - target))
                if releases == 3 { onComplete(max(20, stability / 3)) }
            }.buttonStyle(ActionButtonStyle(tint: GarageStyle.mint))
        }
    }
    private var target: Int { 58 + variant % 25 }
}

struct BearingPreloadMiniGame: View {
    let variant: Int
    let onComplete: (Int) -> Void
    @State private var preload = 10.0
    @State private var rotations = 0

    var body: some View {
        MiniGameShell(title: "Rulman Ön Yükünü Ayarla", instruction: "Somunu kademeli sık, poryayı çevirerek rulmanı oturt ve boşlukla sürtünme arasındaki hedefe gel.") {
            ZStack {
                Circle().stroke(.gray, lineWidth: 24).frame(width: 220, height: 220)
                Circle().fill(GarageStyle.orange).frame(width: CGFloat(72 + preload * 2), height: CGFloat(72 + preload * 2))
                Image(systemName: "arrow.triangle.2.circlepath").font(.largeTitle).rotationEffect(.degrees(Double(rotations * 45)))
            }
            Text("Ön yük: \(preload, specifier: "%.1f") Nm • döndürme \(rotations)/3")
                .font(.headline.monospacedDigit())
            Slider(value: $preload, in: 5...35, step: 0.5).tint(GarageStyle.orange)
            Button("Poryayı Döndür") { rotations = min(3, rotations + 1) }
                .buttonStyle(ActionButtonStyle(tint: GarageStyle.raised, foreground: .white))
            Button("Kopilyayı Tak") {
                let rotationPenalty = max(0, 3 - rotations) * 12
                onComplete(max(20, 100 - Int(abs(preload - target) * 7) - rotationPenalty))
            }.buttonStyle(ActionButtonStyle(tint: GarageStyle.mint))
        }
    }
    private var target: Double { Double(28 + variant % 25) / 2 }
}

struct CVBootGreaseMiniGame: View {
    let variant: Int
    let onComplete: (Int) -> Void
    @State private var chambers = [0.0, 0.0, 0.0]
    @State private var selected = 0

    var body: some View {
        MiniGameShell(title: "Aks Körüğüne Gres Dağıt", instruction: "Gresi tek noktaya yığma; mafsalın üç bölgesine dengeli doldur ve körük kelepçesini kapat.") {
            HStack(spacing: 10) {
                ForEach(chambers.indices, id: \.self) { index in
                    Button { selected = index } label: {
                        VStack {
                            Circle().trim(from: 0, to: chambers[index] / 100)
                                .stroke(index == selected ? GarageStyle.orange : GarageStyle.mint, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                                .rotationEffect(.degrees(-90)).frame(width: 88, height: 88)
                            Text("B\(index + 1) %\(Int(chambers[index]))").font(.caption.bold())
                        }
                    }.buttonStyle(.plain)
                }
            }
            Button("Seçili Bölgeye Gres Bas") { chambers[selected] = min(100, chambers[selected] + Double(8 + variant % 7)) }
                .buttonStyle(ActionButtonStyle(tint: GarageStyle.orange))
            Button("Kelepçeyi Kapat") {
                let spread = (chambers.max() ?? 0) - (chambers.min() ?? 0)
                let average = chambers.reduce(0, +) / 3
                onComplete(max(20, 100 - Int(spread * 2 + abs(average - 72))))
            }.buttonStyle(ActionButtonStyle(tint: GarageStyle.mint))
        }
    }
}
