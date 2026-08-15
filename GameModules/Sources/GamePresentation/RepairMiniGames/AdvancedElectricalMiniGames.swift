import SwiftUI

struct IgnitionCoilOrderMiniGame: View {
    let variant: Int
    let onComplete: (Int) -> Void
    @State private var selected: [Int] = []
    @State private var mistakes = 0

    var body: some View {
        MiniGameShell(title: "Bobin Soketlerini Sırala", instruction: "Silindir ateşleme sırasına göre bobin soketlerini tak; yanlış soket motoru tekletir.") {
            HStack(spacing: 12) {
                ForEach(1...4, id: \.self) { cylinder in
                    Button { tap(cylinder) } label: {
                        VStack {
                            Image(systemName: selected.contains(cylinder) ? "checkmark.circle.fill" : "bolt.horizontal.circle.fill")
                                .font(.title)
                            Text("Silindir \(cylinder)").font(.caption2.bold())
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 15)
                        .background(selected.contains(cylinder) ? GarageStyle.mint : GarageStyle.raised, in: RoundedRectangle(cornerRadius: 12))
                    }.buttonStyle(.plain)
                }
            }
            Text("Sıra: \(order.map(String.init).joined(separator: "-")) • hata \(mistakes)")
                .font(.headline.monospacedDigit())
        }
    }

    private var order: [Int] { variant.isMultiple(of: 2) ? [1, 3, 4, 2] : [1, 2, 4, 3] }
    private func tap(_ cylinder: Int) {
        guard selected.count < order.count else { return }
        if cylinder == order[selected.count] {
            selected.append(cylinder)
            if selected.count == order.count { onComplete(max(25, 100 - mistakes * 16)) }
        } else { mistakes += 1 }
    }
}

struct FuseTraceMiniGame: View {
    let variant: Int
    let onComplete: (Int) -> Void
    @State private var checks = 0
    @State private var found = false

    var body: some View {
        MiniGameShell(title: "Atık Sigortayı Bul", instruction: "Kapaktaki devre ve amper ipucuna göre doğru sigortayı seç; daha yüksek amper takmak tesisatı korumaz.") {
            Text("Aranan: \(circuit) • \(amps[target])A").font(.headline).foregroundStyle(GarageStyle.orange)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                ForEach(0..<8, id: \.self) { index in
                    Button {
                        checks += 1
                        if index == target { found = true; onComplete(max(30, 105 - checks * 10)) }
                    } label: {
                        VStack {
                            Image(systemName: index == target && found ? "bolt.slash.fill" : "bolt.fill")
                            Text("\(amps[index])A").font(.caption.bold())
                        }.frame(maxWidth: .infinity).padding(.vertical, 14)
                    }.buttonStyle(ActionButtonStyle(tint: fuseColor(amps[index])))
                }
            }
        }
    }

    private let amps = [5, 10, 15, 20, 10, 25, 15, 30]
    private var target: Int { variant % 8 }
    private var circuit: String { ["kısa far", "cam motoru", "yakıt pompası", "korna"][variant % 4] }
    private func fuseColor(_ amp: Int) -> Color { amp <= 10 ? .red : (amp <= 20 ? .blue : .green) }
}

struct WireContinuityMiniGame: View {
    let variant: Int
    let onComplete: (Int) -> Void
    @State private var measured: Set<Int> = []
    @State private var mistakes = 0

    var body: some View {
        MiniGameShell(title: "Kablo Sürekliliğini Ölç", instruction: "Multimetreyi hattın iki ucuna bağla; sonsuz direnç gösteren kopuk hattı bul ve onar.") {
            ForEach(0..<4, id: \.self) { line in
                Button {
                    measured.insert(line)
                    if line == broken { onComplete(max(35, 100 - mistakes * 14)) } else { mistakes += 1 }
                } label: {
                    HStack {
                        Circle().fill(lineColor(line)).frame(width: 24, height: 24)
                        Rectangle().fill(lineColor(line)).frame(height: 5)
                        Text(measured.contains(line) ? (line == broken ? "OL • KOPUK" : "0.3 Ω") : "ÖLÇ")
                            .font(.caption.bold().monospacedDigit()).frame(width: 90)
                    }
                }.buttonStyle(ActionButtonStyle(tint: GarageStyle.raised, foreground: .white))
            }
        }
    }

    private var broken: Int { variant % 4 }
    private func lineColor(_ line: Int) -> Color { [.blue, .yellow, .green, .purple][line] }
}

struct WindowRegulatorMiniGame: View {
    let variant: Int
    let onComplete: (Int) -> Void
    @State private var leftRail = 25.0
    @State private var rightRail = 75.0

    var body: some View {
        MiniGameShell(title: "Cam Krikosunu Hizala", instruction: "Camı iki kızakta aynı yükseklikte tut; eğri bağlantı camı sıkıştırır.") {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 18).stroke(.gray, lineWidth: 8).frame(height: 230)
                Rectangle().fill(.blue.opacity(0.45)).frame(height: CGFloat((leftRail + rightRail) / 2 * 1.8))
                    .rotationEffect(.degrees((rightRail - leftRail) / 8))
            }
            rail("Sol kızak", value: $leftRail)
            rail("Sağ kızak", value: $rightRail)
            Button("Camı Yukarı-Aşağı Dene") {
                let levelError = abs(leftRail - rightRail)
                let heightError = abs((leftRail + rightRail) / 2 - target)
                onComplete(max(20, 100 - Int(levelError * 2 + heightError)))
            }.buttonStyle(ActionButtonStyle(tint: GarageStyle.mint))
        }
    }
    private func rail(_ title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading) { Text(title).font(.caption.bold()); Slider(value: value, in: 20...85).tint(GarageStyle.orange) }
    }
    private var target: Double { Double(48 + variant % 20) }
}

struct HeadlightAimMiniGame: View {
    let variant: Int
    let onComplete: (Int) -> Void
    @State private var horizontal = 0.2
    @State private var vertical = 0.8

    var body: some View {
        MiniGameShell(title: "Far Hüzmesini Ayarla", instruction: "Işık kesim çizgisini hedef noktasına getir; karşıdan gelenin gözünü almayacak kadar aşağıda tut.") {
            GeometryReader { geometry in
                ZStack {
                    RoundedRectangle(cornerRadius: 14).fill(.black)
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: geometry.size.height * vertical))
                        path.addLine(to: CGPoint(x: geometry.size.width * horizontal, y: geometry.size.height * vertical))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height * max(0.1, vertical - 0.18)))
                    }.stroke(.yellow, lineWidth: 6)
                    Image(systemName: "scope").font(.title).foregroundStyle(GarageStyle.mint)
                        .position(x: geometry.size.width * targetX, y: geometry.size.height * targetY)
                }
            }.frame(height: 220)
            Slider(value: $horizontal, in: 0.1...0.9).tint(GarageStyle.orange).accessibilityLabel("Far yatay ayarı")
            Slider(value: $vertical, in: 0.2...0.9).tint(GarageStyle.orange).accessibilityLabel("Far düşey ayarı")
            Button("Far Cihazında Onayla") {
                let error = abs(horizontal - targetX) + abs(vertical - targetY)
                onComplete(max(20, 100 - Int(error * 150)))
            }.buttonStyle(ActionButtonStyle(tint: GarageStyle.mint))
        }
    }
    private var targetX: Double { Double(35 + variant % 31) / 100 }
    private var targetY: Double { Double(52 + variant % 19) / 100 }
}
