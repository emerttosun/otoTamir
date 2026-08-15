import GameDomain
import SwiftUI

struct BeltTensionMiniGame: View {
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

struct CoolantBleedMiniGame: View {
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

struct HeadGasketTorqueMiniGame: View {
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

struct BatteryTerminalMiniGame: View {
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

struct ChargingVoltageMiniGame: View {
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

struct SensorGapMiniGame: View {
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

