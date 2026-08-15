import GameDomain
import SwiftUI

struct RestoredBodyHistoryView: View {
    let project: ProjectCar
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Restorasyon sonrası işlem geçmişi")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(restoredPanels) { panel in
                    historyRow(
                        title: panel.panel.title,
                        detail: panel.condition.title,
                        color: panelColor(panel.condition)
                    )
                }

                if !repairedStructures.isEmpty {
                    Divider().overlay(.white.opacity(0.12))
                    Text("ŞASİ VE TAŞIYICI YAPI")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(GarageStyle.orange)
                    ForEach(repairedStructures) { damage in
                        historyRow(
                            title: damage.area.title,
                            detail: restoredStructureTitle(damage.condition),
                            color: GarageStyle.orange
                        )
                    }
                }

                if project.airbagsDeployed {
                    Divider().overlay(.white.opacity(0.12))
                    historyRow(
                        title: "Airbag sistemi",
                        detail: "Açan sistem yenilenip arıza kaydı silinmeden kontrol edildi",
                        color: GarageStyle.mint
                    )
                }

                Text("Hasar kaydı: \(project.recordedDamage.liraText) • Onarılabilir ağır hasar geçmişi")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 10)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Label("Kaporta ve Hasar Bilgisi", systemImage: "car.side.rear.and.collision.and.car.side.front")
                    .font(.caption.weight(.bold))
                Text(summary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .tint(GarageStyle.orange)
        .padding(10)
        .background(GarageStyle.raised.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityHint("Restorasyon sonrası kaporta ve taşıyıcı yapı geçmişini açar")
    }

    private var restoredPanels: [RestoredPanel] {
        project.panelDamages.compactMap { damage in
            guard VehiclePanel.exteriorCases.contains(damage.panel), damage.condition != .original else {
                return nil
            }
            let restoredCondition: RestoredPanelCondition = switch damage.condition {
            case .painted, .damaged: .painted
            case .replaced, .heavyDamage, .missing: .replaced
            case .original: .original
            }
            return RestoredPanel(panel: damage.panel, condition: restoredCondition)
        }
    }

    private var repairedStructures: [StructuralDamage] {
        project.structuralDamages.filter { $0.condition.requiresRepair }
    }

    private var summary: String {
        let paintedCount = restoredPanels.count { $0.condition == .painted }
        let replacedCount = restoredPanels.count { $0.condition == .replaced }
        return "\(replacedCount) değişen • \(paintedCount) boyalı • \(repairedStructures.count) yapısal onarım"
    }

    private func restoredStructureTitle(_ condition: StructuralCondition) -> String {
        switch condition {
        case .intact: "İşlemsiz • ölçü normal"
        case .measurementDeviation: "Şasi ölçümünde doğrultuldu"
        case .bent: "Doğrultuldu ve ölçüsü doğrulandı"
        case .cracked: "Çatlak onarılıp kaynak kontrolü yapıldı"
        case .cutOrWelded: "Kesme-kaynak onarımı yapıldı"
        }
    }

    private func historyRow(title: String, detail: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle().fill(color).frame(width: 9, height: 9).padding(.top, 4)
            Text(title).font(.caption)
            Spacer(minLength: 8)
            Text(detail)
                .font(.caption.weight(.semibold))
                .multilineTextAlignment(.trailing)
                .foregroundStyle(color)
        }
    }

    private func panelColor(_ condition: RestoredPanelCondition) -> Color {
        switch condition {
        case .original: .gray
        case .painted: .blue
        case .replaced: GarageStyle.danger
        }
    }
}

private struct RestoredPanel: Identifiable {
    var id: VehiclePanel { panel }
    let panel: VehiclePanel
    let condition: RestoredPanelCondition
}

private enum RestoredPanelCondition: Equatable {
    case original
    case painted
    case replaced

    var title: String {
        switch self {
        case .original: "Orijinal"
        case .painted: "Boyalı"
        case .replaced: "Değişen"
        }
    }
}
