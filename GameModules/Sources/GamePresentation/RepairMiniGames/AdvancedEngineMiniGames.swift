import SwiftUI

struct SparkPlugGapMiniGame: View {
    let variant: Int
    let onComplete: (Int) -> Void
    @State private var gap = 0.6

    var body: some View {
        MiniGameShell(title: "Buji Tırnak Aralığı", instruction: "Sentil değerine göre yan elektrodu ayarla; dar aralık zayıf, geniş aralık düzensiz kıvılcım yapar.") {
            ZStack {
                Capsule().fill(.gray).frame(width: 210, height: 58)
                Rectangle().fill(.black).frame(width: CGFloat(gap * 80), height: 18)
                HStack { Image(systemName: "bolt.fill"); Spacer(); Image(systemName: "bolt.fill") }
                    .foregroundStyle(GarageStyle.orange).frame(width: 140)
            }
            Text("Aralık: \(gap, specifier: "%.2f") mm • hedef \(target, specifier: "%.2f") mm")
                .font(.headline.monospacedDigit())
            Slider(value: $gap, in: 0.5...1.2, step: 0.05).tint(GarageStyle.orange)
                .accessibilityLabel("Buji tırnak aralığı")
            Button("Sentille Kontrol Et") { onComplete(max(20, 100 - Int(abs(gap - target) * 180))) }
                .buttonStyle(ActionButtonStyle(tint: GarageStyle.mint))
        }
    }

    private var target: Double { Double(14 + variant % 7) / 20 }
}

struct InjectorBalanceMiniGame: View {
    let variant: Int
    let onComplete: (Int) -> Void
    @State private var values = [42.0, 68.0, 34.0, 76.0]

    var body: some View {
        MiniGameShell(title: "Enjektör Dönüşünü Dengele", instruction: "Dört enjektörün test haznesini aynı seviyeye getir; fazla dönüş yapanı kıs, düşük kalanı aç.") {
            HStack(alignment: .bottom, spacing: 12) {
                ForEach(values.indices, id: \.self) { index in
                    VStack {
                        GeometryReader { geometry in
                            RoundedRectangle(cornerRadius: 8)
                                .fill(GarageStyle.mint)
                                .frame(height: geometry.size.height * values[index] / 100)
                                .frame(maxHeight: .infinity, alignment: .bottom)
                        }
                        Text("\(Int(values[index]))").font(.caption.monospacedDigit())
                        Stepper("E\(index + 1)", value: $values[index], in: 20...90, step: 3).labelsHidden()
                    }
                }
            }.frame(height: 230)
            Button("Dönüş Testini Bitir") {
                let spread = (values.max() ?? 0) - (values.min() ?? 0)
                let centerError = abs((values.reduce(0, +) / 4) - target)
                onComplete(max(20, 100 - Int(spread * 3 + centerError)))
            }.buttonStyle(ActionButtonStyle(tint: GarageStyle.mint))
        }
    }

    private var target: Double { Double(48 + variant % 9) }
}

struct WaterPumpSealMiniGame: View {
    let variant: Int
    let onComplete: (Int) -> Void
    @State private var step = 0
    @State private var mistakes = 0

    var body: some View {
        MiniGameShell(title: "Pompa Contasını Oturt", instruction: "Contayı kaydırmadan cıvataları karşılıklı ve kademeli sık; tek köşeyi birden bastırma.") {
            ZStack {
                Circle().stroke(GarageStyle.mint, lineWidth: 18).frame(width: 210, height: 210)
                Image(systemName: "fanblades.fill").font(.system(size: 82)).foregroundStyle(.gray)
                ForEach(0..<6, id: \.self) { bolt in
                    Button { tap(bolt) } label: {
                        Text("\(bolt + 1)").font(.caption.bold()).frame(width: 42, height: 42)
                            .background(step > sequence.firstIndex(of: bolt) ?? 99 ? GarageStyle.mint : GarageStyle.orange, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .offset(x: cos(Double(bolt) * .pi / 3) * 125, y: sin(Double(bolt) * .pi / 3) * 125)
                }
            }.frame(height: 290)
            Text("Sıra \(step)/6 • hata \(mistakes)").font(.headline.monospacedDigit())
        }
    }

    private var sequence: [Int] { variant.isMultiple(of: 2) ? [0, 3, 1, 4, 2, 5] : [2, 5, 1, 4, 0, 3] }
    private func tap(_ bolt: Int) {
        guard step < sequence.count else { return }
        if bolt == sequence[step] {
            step += 1
            if step == sequence.count { onComplete(max(25, 100 - mistakes * 14)) }
        } else { mistakes += 1 }
    }
}

struct TurboPressureMiniGame: View {
    let variant: Int
    let onComplete: (Int) -> Void
    @State private var wastegate = 45.0
    @State private var throttle = 55.0

    var body: some View {
        MiniGameShell(title: "Turbo Basıncını Ayarla", instruction: "Gaz yükünü sabitle, wastegate kolunu ayarla ve basıncı güvenli hedef bandına getir.") {
            ZStack {
                Circle().stroke(.gray.opacity(0.4), lineWidth: 18).frame(width: 190, height: 190)
                Image(systemName: "gauge.with.dots.needle.67percent").font(.system(size: 78)).foregroundStyle(GarageStyle.orange)
                Text("\(pressure, specifier: "%.2f") bar").font(.title2.bold().monospacedDigit()).offset(y: 62)
            }
            setting("Gaz yükü", value: $throttle)
            setting("Wastegate", value: $wastegate)
            Text("Hedef: \(target, specifier: "%.2f") bar").font(.caption.bold()).foregroundStyle(.secondary)
            Button("Basınç Testini Kaydet") { onComplete(max(20, 100 - Int(abs(pressure - target) * 85))) }
                .buttonStyle(ActionButtonStyle(tint: GarageStyle.mint))
        }
    }

    private func setting(_ title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading) { Text(title).font(.caption.bold()); Slider(value: value, in: 20...90).tint(GarageStyle.orange) }
    }
    private var pressure: Double { 0.25 + throttle / 100 * 0.9 + wastegate / 100 * 0.65 }
    private var target: Double { Double(105 + variant % 36) / 100 }
}

struct OilLeakTraceMiniGame: View {
    let variant: Int
    let onComplete: (Int) -> Void
    @State private var selected: [Int] = []
    @State private var mistakes = 0

    var body: some View {
        MiniGameShell(title: "Yağ Kaçağını İzle", instruction: "Temizlenen motorda UV izini aşağıdaki damladan yukarıdaki ilk ıslak noktaya doğru takip et.") {
            VStack(spacing: 9) {
                ForEach(0..<4, id: \.self) { row in
                    HStack(spacing: 14) {
                        ForEach(0..<3, id: \.self) { column in
                            let point = row * 3 + column
                            Button { tap(point) } label: {
                                Image(systemName: selected.contains(point) ? "drop.fill" : "circle.fill")
                                    .font(.title2).foregroundStyle(selected.contains(point) ? GarageStyle.mint : .purple.opacity(0.7))
                                    .frame(width: 68, height: 48).background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
            Text("İz \(selected.count)/\(path.count) • yanlış nokta \(mistakes)").font(.headline.monospacedDigit())
        }
    }

    private var path: [Int] { variant.isMultiple(of: 2) ? [10, 7, 4, 1] : [11, 8, 7, 4, 3] }
    private func tap(_ point: Int) {
        guard selected.count < path.count else { return }
        if point == path[selected.count] {
            selected.append(point)
            if selected.count == path.count { onComplete(max(20, 100 - mistakes * 15)) }
        } else { mistakes += 1 }
    }
}
