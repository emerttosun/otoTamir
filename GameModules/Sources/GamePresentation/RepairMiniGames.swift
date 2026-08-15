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

private struct FluidFillMiniGame: View {
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

private struct TimingMiniGame: View {
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

private struct BeltTensionMiniGame: View {
    let variant: Int
    let onComplete: (Int) -> Void
    @State private var tension = 0.25

    var body: some View {
        MiniGameShell(
            title: "Kayış Gerginliği",
            instruction: "Gergi rulmanını ayarla. Kayış ne ötecek kadar gevşek ne de rulmanı yoracak kadar sıkı olmalı."
        ) {
            ZStack {
                Capsule().stroke(.white.opacity(0.35), lineWidth: 12).frame(width: 250, height: 92)
                Image(systemName: "arrow.down").font(.title.bold()).foregroundStyle(GarageStyle.orange)
                    .offset(y: CGFloat(tension * 42 - 8))
            }
            Slider(value: $tension, in: 0...1).tint(GarageStyle.orange)
                .accessibilityLabel("Kayış gerginliği")
            Text("Esneme: \(Int((1 - tension) * 14)) mm • hedef \(targetMillimeters) mm")
                .font(.headline.monospacedDigit())
            Button("Gergiyi Kilitle") {
                let measured = Int((1 - tension) * 14)
                onComplete(max(20, 100 - abs(measured - targetMillimeters) * 14))
            }
            .buttonStyle(ActionButtonStyle(tint: GarageStyle.mint))
        }
    }

    private var targetMillimeters: Int { 5 + variant % 4 }
}

private struct CoolantBleedMiniGame: View {
    let variant: Int
    let onComplete: (Int) -> Void
    @State private var coolant = 0.28
    @State private var trappedAir = 3
    @State private var mistakes = 0

    var body: some View {
        MiniGameShell(
            title: "Soğutma Suyunu Doldur ve Havasını Al",
            instruction: "Seviyeyi tamamla; sonra kabarcık çıktıkça hava alma tapasını kısa kısa aç."
        ) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.4), lineWidth: 4)
                RoundedRectangle(cornerRadius: 16)
                    .fill(coolant > 0.86 ? GarageStyle.danger : .cyan)
                    .frame(height: 190 * coolant)
                if trappedAir > 0 {
                    ForEach(0..<trappedAir, id: \.self) { index in
                        Circle().stroke(.white, lineWidth: 2).frame(width: 18, height: 18)
                            .offset(x: CGFloat(index - 1) * 28, y: -CGFloat(20 + index * 25))
                    }
                }
            }
            .frame(width: 170, height: 190)
            HStack {
                Button("Sıvı Ekle") { coolant = min(1, coolant + Double(7 + variant % 4) / 100) }
                Button("Hava Al") {
                    if coolant >= 0.68, trappedAir > 0 { trappedAir -= 1 } else { mistakes += 1 }
                }
            }
            .buttonStyle(ActionButtonStyle(tint: GarageStyle.orange))
            Text("Seviye %\(Int(coolant * 100)) • hava cebi \(trappedAir)")
                .font(.headline.monospacedDigit())
            Button("Kapağı Kapat") {
                let levelError = abs(coolant - 0.78)
                let airPenalty = trappedAir * 20
                onComplete(max(20, Int(100 - levelError * 160) - airPenalty - mistakes * 8))
            }
            .buttonStyle(ActionButtonStyle(tint: GarageStyle.mint))
        }
    }
}

private struct HeadGasketTorqueMiniGame: View {
    let variant: Int
    let onComplete: (Int) -> Void
    @State private var step = 0
    @State private var mistakes = 0
    @State private var tightened: Set<String> = []

    var body: some View {
        MiniGameShell(
            title: "Silindir Kapağını Torkla",
            instruction: "Altı kapağı merkezden dışa doğru iki kademede sık. İlk tur ön sıkma, ikinci tur nihai tork."
        ) {
            LazyVGrid(columns: [.init(), .init(), .init()], spacing: 16) {
                ForEach(0..<6, id: \.self) { bolt in
                    Button { tighten(bolt) } label: {
                        ZStack {
                            Circle().fill(isCurrentPassDone(bolt) ? GarageStyle.mint : GarageStyle.raised)
                            Image(systemName: "hexagon.fill").font(.title)
                            Text("\(bolt + 1)").font(.caption.bold()).foregroundStyle(.black)
                        }.frame(width: 66, height: 66)
                    }.buttonStyle(.plain)
                }
            }
            Text("Kademe \(min(2, step / 6 + 1))/2 • Hata \(mistakes)")
                .font(.headline.monospacedDigit())
        }
    }

    private var sequence: [Int] {
        let base = [2, 3, 1, 4, 0, 5]
        let reverse = Array(base.reversed())
        return variant.isMultiple(of: 2) ? base + base : reverse + reverse
    }

    private func isCurrentPassDone(_ bolt: Int) -> Bool {
        tightened.contains("\(step / 6)-\(bolt)")
    }

    private func tighten(_ bolt: Int) {
        guard step < sequence.count else { return }
        guard bolt == sequence[step] else { mistakes += 1; return }
        tightened.insert("\(step / 6)-\(bolt)")
        step += 1
        if step == sequence.count { onComplete(max(25, 100 - mistakes * 10)) }
    }
}

private struct BatteryTerminalMiniGame: View {
    let onComplete: (Int) -> Void
    @State private var step = 0
    @State private var mistakes = 0

    var body: some View {
        MiniGameShell(
            title: "Akü Kutup Başlarını Yenile",
            instruction: "Güvenli sırayla sök, oksidi temizle ve yeni aküyü doğru kutup sırasıyla bağla."
        ) {
            Image(systemName: "battery.100percent").font(.system(size: 100)).foregroundStyle(GarageStyle.mint)
            ForEach(Array(actions.enumerated()), id: \.offset) { index, action in
                Button {
                    if index == step {
                        step += 1
                        if step == actions.count { onComplete(max(30, 100 - mistakes * 15)) }
                    } else { mistakes += 1 }
                } label: {
                    Label(action, systemImage: index < step ? "checkmark.circle.fill" : "circle")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(ActionButtonStyle(tint: index == step ? GarageStyle.orange : GarageStyle.raised, foreground: .white))
                .disabled(index < step)
            }
        }
    }

    private let actions = ["Eksi kutbu sök", "Artı kutbu sök", "Oksidi fırçala", "Artı kutbu bağla", "Eksi kutbu bağla"]
}

private struct ChargingVoltageMiniGame: View {
    let variant: Int
    let onComplete: (Int) -> Void
    @State private var rpm = 900.0
    @State private var loadOn = false
    @State private var measurementStep = 0
    @State private var setupScore = 0

    var body: some View {
        MiniGameShell(
            title: "Şarj Voltajını Ölç",
            instruction: "Multimetre bağlıyken rölanti ve 2.000 devirde, elektrik yükü açık ve kapalı ölçüm al."
        ) {
            ZStack {
                RoundedRectangle(cornerRadius: 18).fill(.black).frame(width: 250, height: 120)
                Text(String(format: "%.2f V", voltage)).font(.system(size: 40, weight: .bold, design: .monospaced)).foregroundStyle(.green)
            }
            Slider(value: $rpm, in: 800...2400, step: 100).tint(GarageStyle.orange)
            Toggle("Far ve fan yükü", isOn: $loadOn).tint(GarageStyle.orange)
            Text("Motor: \(Int(rpm)) dev/dk • ölçüm \(measurementStep)/3").font(.caption.monospacedDigit())
            Text(nextMeasurement)
                .font(.caption.bold()).foregroundStyle(GarageStyle.orange)
            Button("Ölçümü Kaydet") {
                let total = setupScore + currentSetupScore
                let nextStep = measurementStep + 1
                setupScore = total
                measurementStep = nextStep
                if nextStep == 3 { onComplete(max(30, total / 3)) }
            }
            .buttonStyle(ActionButtonStyle(tint: GarageStyle.mint))
            .disabled(measurementStep >= 3)
        }
    }

    private var voltage: Double {
        13.55 + (rpm - 800) / 2000 + (loadOn ? -0.42 : 0) + Double(variant % 5) / 100
    }

    private var nextMeasurement: String {
        switch measurementStep {
        case 0: "1. Rölanti • elektrik yükü kapalı"
        case 1: "2. 2.000 dev/dk • elektrik yükü kapalı"
        default: "3. 2.000 dev/dk • far ve fan açık"
        }
    }

    private var currentSetupScore: Int {
        let targetRPM = measurementStep == 0 ? 900.0 : 2_000.0
        let targetLoad = measurementStep == 2
        let rpmPenalty = Int(abs(rpm - targetRPM) / 12)
        let loadPenalty = loadOn == targetLoad ? 0 : 35
        return max(20, 100 - rpmPenalty - loadPenalty)
    }
}

private struct SensorGapMiniGame: View {
    let variant: Int
    let onComplete: (Int) -> Void
    @State private var gap = 1.8

    var body: some View {
        MiniGameShell(
            title: "Sensör Boşluğunu Ayarla",
            instruction: "Krank sensörünü dişliye değdirmeden hedef hava aralığına getir."
        ) {
            HStack(spacing: CGFloat(gap * 35)) {
                RoundedRectangle(cornerRadius: 6).fill(GarageStyle.orange).frame(width: 65, height: 120)
                Image(systemName: "gearshape.2.fill").font(.system(size: 76))
            }
            Slider(value: $gap, in: 0.2...2.5, step: 0.1).tint(GarageStyle.orange)
            Text(String(format: "Boşluk %.1f mm • hedef %.1f mm", gap, target))
                .font(.headline.monospacedDigit())
            Button("Sensörü Sabitle") {
                onComplete(max(20, 100 - Int(abs(gap - target) * 55)))
            }.buttonStyle(ActionButtonStyle(tint: GarageStyle.mint))
        }
    }

    private var target: Double { Double(6 + variant % 7) / 10 }
}

private struct BrakePadMiniGame: View {
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

private struct ToeAdjustmentMiniGame: View {
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

private struct ClutchCenteringMiniGame: View {
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

private struct BumperClipMiniGame: View {
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

private struct DoorGapMiniGame: View {
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

private struct DentPullMiniGame: View {
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

private struct BoltsMiniGame: View {
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

private struct WiringMiniGame: View {
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

private struct AlignmentMiniGame: View {
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
