import SwiftUI

struct HoodAlignmentMiniGame: View {
    let variant: Int
    let onComplete: (Int) -> Void
    @State private var left = 2.0
    @State private var right = 7.0
    @State private var front = 6.0

    var body: some View {
        MiniGameShell(title: "Kaput Aralıklarını Eşitle", instruction: "Menteşe ve takozları ayarla; sağ-sol boşluk eşit, ön kenar tamponla aynı hizada olsun.") {
            ZStack {
                RoundedRectangle(cornerRadius: 35).stroke(.gray, lineWidth: 9).frame(height: 245)
                RoundedRectangle(cornerRadius: 28).stroke(GarageStyle.orange, lineWidth: 5)
                    .frame(width: 230 + CGFloat(right - left) * 5, height: 190 + CGFloat(front - target) * 4)
                    .offset(x: CGFloat(right - left) * 4)
            }
            gap("Sol aralık", value: $left)
            gap("Sağ aralık", value: $right)
            gap("Ön yükseklik", value: $front)
            Button("Kaputu Kapatıp Kontrol Et") {
                let error = abs(left - target) + abs(right - target) + abs(front - target)
                onComplete(max(20, 100 - Int(error * 14)))
            }.buttonStyle(ActionButtonStyle(tint: GarageStyle.mint))
        }
    }
    private func gap(_ title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading) { Text("\(title): \(value.wrappedValue, specifier: "%.1f") mm").font(.caption.bold()); Slider(value: value, in: 1...8, step: 0.5).tint(GarageStyle.orange) }
    }
    private var target: Double { Double(6 + variant % 6) / 2 }
}

struct PanelWeldMiniGame: View {
    let variant: Int
    let onComplete: (Int) -> Void
    @State private var welded: Set<Int> = []
    @State private var heat = 0
    @State private var mistakes = 0

    var body: some View {
        MiniGameShell(title: "Paneli Nokta Kaynakla Birleştir", instruction: "Sacı çarpıtmamak için yan yana iki noktaya yüklenme; karşılıklı ilerleyip ısıyı dağıt.") {
            VStack(spacing: 12) {
                ForEach(0..<2, id: \.self) { row in
                    HStack(spacing: 12) {
                        ForEach(0..<6, id: \.self) { column in
                            let spot = row * 6 + column
                            Button { weld(spot) } label: {
                                Circle().fill(welded.contains(spot) ? GarageStyle.mint : .gray)
                                    .frame(width: 42, height: 42)
                                    .overlay(Image(systemName: welded.contains(spot) ? "checkmark" : "sparkles"))
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
            SwiftUI.ProgressView(value: Double(heat), total: 100).tint(heat > 75 ? GarageStyle.danger : GarageStyle.orange)
            Text("Kaynak \(welded.count)/12 • ısı %\(heat) • hata \(mistakes)").font(.headline.monospacedDigit())
        }
    }
    private var sequence: [Int] { variant.isMultiple(of: 2) ? [0, 11, 5, 6, 2, 9, 4, 7, 1, 10, 3, 8] : [5, 6, 0, 11, 3, 8, 1, 10, 4, 7, 2, 9] }
    private func weld(_ spot: Int) {
        guard welded.count < sequence.count, !welded.contains(spot) else { return }
        if spot == sequence[welded.count] { heat = max(0, heat - 8) } else { heat += 18; mistakes += 1 }
        welded.insert(spot)
        heat += 9
        if welded.count == sequence.count { onComplete(max(20, 100 - mistakes * 10 - max(0, heat - 75))) }
    }
}

struct PaintLayersMiniGame: View {
    let variant: Int
    let onComplete: (Int) -> Void
    @State private var completed: [Int] = []
    @State private var thickness = [0.0, 0.0, 0.0]
    @State private var mistakes = 0

    var body: some View {
        MiniGameShell(title: "Boya Katmanlarını Uygula", instruction: "Yüzeyi hazırla; astar, renk ve verniği doğru sırada, ince ve dengeli katlarla uygula.") {
            HStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { step in
                    Button { perform(step) } label: {
                        VStack {
                            Image(systemName: icons[step]).font(.title2)
                            Text(names[step]).font(.caption2.bold())
                        }.frame(maxWidth: .infinity).padding(.vertical, 12)
                    }.buttonStyle(ActionButtonStyle(tint: completed.contains(step) ? GarageStyle.mint : GarageStyle.raised, foreground: .white))
                }
            }
            ForEach(thickness.indices, id: \.self) { layer in
                VStack(alignment: .leading) {
                    Text("\(names[layer + 1]): \(Int(thickness[layer])) µm").font(.caption.bold())
                    SwiftUI.ProgressView(value: thickness[layer], total: 60).tint(layer == 1 ? GarageStyle.orange : .gray)
                }
            }
            if completed.count == 4 {
                Button("Boya Kalınlığını Ölç") {
                    let target = Double(30 + variant % 16)
                    let error = thickness.reduce(0) { $0 + abs($1 - target) }
                    onComplete(max(20, 100 - Int(error) - mistakes * 12))
                }.buttonStyle(ActionButtonStyle(tint: GarageStyle.mint))
            }
        }
    }
    private let names = ["Zımpara", "Astar", "Renk", "Vernik"]
    private let icons = ["scribble", "paintbrush.fill", "paintpalette.fill", "sparkles"]
    private func perform(_ step: Int) {
        guard !completed.contains(step) else { return }
        if step != completed.count { mistakes += 1; return }
        completed.append(step)
        if step > 0 { thickness[step - 1] = Double(26 + (variant + step * 7) % 25) }
    }
}
