import Foundation
import GameDomain
import GameLogic
import SwiftUI

struct AuctionView: View {
    @ObservedObject var store: GameStore

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if let market = store.state.auction, !market.lots.isEmpty {
                        marketHeader
                        ForEach(market.lots) { lot in
                            SalvageLotCard(
                                lot: lot,
                                catalog: store.catalog,
                                hasBodyPaintBooth: currentFacilities.contains(.bodyPaintBooth)
                            ) {
                                store.send(.purchaseAuctionLot(lot.id))
                            }
                        }
                    } else {
                        emptyMarket
                    }
                }
                .padding(.vertical, 8)
            }
            .task {
                guard let focus = ProcessInfo.processInfo.environment["OTOTAMIR_QA_FOCUS"] else { return }
                await Task.yield()
                proxy.scrollTo(focus, anchor: .top)
            }
        }
    }

    private var emptyMarket: some View {
        VStack(spacing: 14) {
            Image(systemName: "car.side.rear.open.fill")
                .font(.system(size: 46))
                .foregroundStyle(GarageStyle.orange)
            Text("Hasarlı araç stoğu yenileniyor").font(.title3.bold())
            Text("Yeni sigorta çıkması araçlar sonraki ihale yenilemesinde gelir.")
                .font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .garageCard()
        .padding(.horizontal, 12)
        .padding(.top, 18)
    }

    private var currentFacilities: [ShopFacility] {
        store.catalog.shopLevel(store.state.shopLevel)?.facilities ?? []
    }

    private var marketHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("HASARLI ARAÇ İHALESİ")
                .font(.caption.weight(.black)).foregroundStyle(GarageStyle.orange)
            Text("Sabit ihale bedeli • sigorta çıkması ağır kazalı araçlar").font(.title3.bold())
            Text("Bu pazarda yalnız eksper tarafından onarılabilir kabul edilen ağır hasarlı araçlar bulunur. Tam hasarlı ve hurda tescilli araçlar satın alınamaz.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .garageCard()
        .padding(.horizontal, 12)
    }
}

private struct SalvageLotCard: View {
    let lot: AuctionLot
    let catalog: ContentCatalog
    let hasBodyPaintBooth: Bool
    let purchase: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(vehicle?.name ?? "Kazalı Araç").font(.headline)
                    Text(vehicle?.category ?? "").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(lot.severity.title)
                    .font(.caption2.bold()).foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(GarageStyle.danger, in: Capsule())
            }

            HStack(spacing: 7) {
                statusChip(lot.startsAndDrives ? "Çalışır / yürür" : "Çalışmaz / çekici", good: lot.startsAndDrives)
                statusChip(lot.airbagsDeployed ? "Airbag açmış" : "Airbag sağlam", good: !lot.airbagsDeployed)
            }

            VehicleInspectionDiagram(
                damages: lot.panelDamages,
                structuralDamages: lot.structuralDamages
            )

            VStack(alignment: .leading, spacing: 7) {
                Text("HASARLI VE EKSİK DIŞ PARÇALAR").font(.caption2.bold()).foregroundStyle(GarageStyle.orange)
                ForEach(lot.panelDamages.filter { $0.condition != .original && VehiclePanel.exteriorCases.contains($0.panel) }) { damage in
                    HStack {
                        Text(damage.panel.title).font(.caption)
                        Spacer()
                        Text(damage.condition.title)
                            .font(.caption.bold()).foregroundStyle(conditionColor(damage.condition))
                    }
                }
            }

            if let vehicle {
                investmentReport(vehicle: vehicle)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("MEKANİK VE ELEKTRİK KUSURLARI").font(.caption2.bold()).foregroundStyle(GarageStyle.orange)
                ForEach(lot.mechanicalFaultIDs, id: \.self) { id in
                    if let fault = catalog.fault(id: id) {
                        Label("\(fault.name) • \(fault.partName)", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption).foregroundStyle(.white.opacity(0.84))
                    }
                }
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Kayıtlı hasar").font(.caption2).foregroundStyle(.secondary)
                    Text(lot.recordedDamage.liraText).font(.caption.bold().monospacedDigit())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("İhale satış bedeli").font(.caption2).foregroundStyle(.secondary)
                    Text(lot.fixedPrice.liraText)
                        .font(.title3.bold().monospacedDigit()).foregroundStyle(GarageStyle.mint)
                }
            }

            Button(action: purchase) {
                Label(lot.severity == .heavy ? "İhaleden Satın Al" : "Hurda Araç Satın Alınamaz", systemImage: "cart.fill")
            }
            .buttonStyle(ActionButtonStyle(tint: GarageStyle.mint))
            .disabled(lot.severity != .heavy)
            .id("purchase")
        }
        .garageCard()
        .padding(.horizontal, 12)
    }

    private func investmentReport(vehicle: VehicleDefinition) -> some View {
        let estimate = VehicleTradingRules.investmentEstimate(
            lot: lot,
            vehicle: vehicle,
            faults: lot.mechanicalFaultIDs.compactMap { catalog.fault(id: $0) },
            hasBodyPaintBooth: hasBodyPaintBooth
        )
        return VStack(alignment: .leading, spacing: 7) {
            Text("USTA HESABI • TAHMİNİ").font(.caption2.bold()).foregroundStyle(GarageStyle.orange)
            estimateRow("Onarım gideri", low: estimate.repairLow, high: estimate.repairHigh)
            estimateRow("Toplam yatırım", low: estimate.totalInvestmentLow, high: estimate.totalInvestmentHigh)
            estimateRow("Adil satış bandı", low: estimate.fairSaleLow, high: estimate.fairSaleHigh)
            estimateRow("Olası kâr / zarar", low: estimate.profitLow, high: estimate.profitHigh)
            Text("Bu hesap parçaların fiyatına, kaporta işine ve piyasa ilgisine göre değişir; kâr garantisi değildir.")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(10)
        .background(GarageStyle.raised.opacity(0.58), in: RoundedRectangle(cornerRadius: 11))
        .id("investment")
    }

    private func statusChip(_ text: String, good: Bool) -> some View {
        Text(text)
            .font(.caption2.bold())
            .foregroundStyle(good ? GarageStyle.mint : GarageStyle.danger)
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(GarageStyle.raised, in: Capsule())
    }

    private func conditionColor(_ condition: PanelCondition) -> Color {
        switch condition {
        case .original: Color(red: 0.57, green: 0.59, blue: 0.61)
        case .painted: .blue
        case .replaced: Color(red: 1.0, green: 0.30, blue: 0.20)
        case .damaged: .purple
        case .heavyDamage: GarageStyle.danger
        case .missing: .secondary
        }
    }

    private var vehicle: VehicleDefinition? { catalog.vehicle(id: lot.vehicleID) }

    private func estimateRow(_ title: String, low: Money, high: Money) -> some View {
        HStack {
            Text(title).font(.caption)
            Spacer()
            Text("\(low.liraText) – \(high.liraText)")
                .font(.caption.bold().monospacedDigit())
                .foregroundStyle(low < .zero || high < .zero ? GarageStyle.danger : .white)
        }
    }
}
