import Foundation
import GameDomain
import GameLogic
import SwiftUI

struct SalvageMarketView: View {
    @ObservedObject var store: GameStore

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if let market = store.state.salvageMarket, !market.listings.isEmpty {
                        marketHeader
                        ForEach(market.listings) { listing in
                            SalvageVehicleListingCard(
                                listing: listing,
                                catalog: store.catalog,
                                hasBodyPaintBooth: currentFacilities.contains(.bodyPaintBooth),
                                inspect: { kind in
                                    store.send(.inspectSalvageVehicle(listingID: listing.id, kind: kind))
                                }
                            ) {
                                store.send(.purchaseSalvageVehicle(listing.id))
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
            Text("Yeni sigorta çıkması araçlar pazar yenilendiğinde gelir.")
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
            Text("HASARLI ARAÇ PAZARI")
                .font(.caption.weight(.black)).foregroundStyle(GarageStyle.orange)
            Text("Sabit satış bedeli • sigorta çıkması ağır kazalı araçlar").font(.title3.bold())
            Text("Bu pazarda yalnız eksper tarafından onarılabilir kabul edilen ağır hasarlı araçlar bulunur. Tam hasarlı ve hurda tescilli araçlar satın alınamaz.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .garageCard()
        .padding(.horizontal, 12)
    }
}

private struct SalvageVehicleListingCard: View {
    let listing: SalvageVehicleListing
    let catalog: ContentCatalog
    let hasBodyPaintBooth: Bool
    let inspect: (SalvageInspectionKind) -> Void
    let purchase: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(vehicle?.name ?? "Kazalı Araç").font(.headline)
                    Text(vehicle?.category ?? "").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(listing.severity.title)
                    .font(.caption2.bold()).foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(GarageStyle.danger, in: Capsule())
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("EKSPER ÖZETİ").font(.caption2.bold()).foregroundStyle(GarageStyle.orange)
                Label(impactSummary, systemImage: "car.rear.road.lane")
                Label(
                    listing.airbagsDeployed ? "Hava yastıkları açmış" : "Hava yastığı sistemi kayıtlı olarak sağlam",
                    systemImage: "shield.lefthalf.filled"
                )
                Label(
                    listing.startsAndDrives ? "Araç çalışıyor ve yürür durumda" : "Araç çalışmıyor veya çekici gerekiyor",
                    systemImage: "engine.combustion.fill"
                )
                Text("Mekanik ve taşıyıcı ayrıntılar inceleme yapılmadan belirsizdir.")
                    .foregroundStyle(.secondary)
            }
            .font(.caption)

            inspectionControls

            if !listing.performedInspections.isEmpty {
                VehicleInspectionDiagram(
                    damages: listing.panelDamages,
                    structuralDamages: listing.structuralDamages,
                    knownPanels: listing.revealedPanelIDs,
                    knownStructuralAreas: listing.revealedStructuralAreas
                )
            }

            if listing.performedInspections.contains(.body) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("TESPİT EDİLEN DIŞ PARÇALAR").font(.caption2.bold()).foregroundStyle(GarageStyle.orange)
                    ForEach(revealedPanelDamages) { damage in
                        HStack {
                            Text(damage.panel.title).font(.caption)
                            Spacer()
                            Text(damage.condition.title)
                                .font(.caption.bold()).foregroundStyle(conditionColor(damage.condition))
                        }
                    }
                }
            }

            if !listing.revealedFaultIDs.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    Text("TESPİT EDİLEN SİSTEM KUSURLARI").font(.caption2.bold()).foregroundStyle(GarageStyle.orange)
                    ForEach(listing.revealedFaultIDs, id: \.self) { id in
                        if let fault = catalog.fault(id: id) {
                            Label(
                                "\(fault.name) • \(catalog.part(for: fault)?.name ?? "parça kaydı eksik")",
                                systemImage: "exclamationmark.triangle.fill"
                            )
                                .font(.caption).foregroundStyle(.white.opacity(0.84))
                        }
                    }
                }
            } else if listing.performedInspections.contains(.underbody) || listing.performedInspections.contains(.systems) {
                Label("Bu kontrollerde kesinleşen ek sistem kusuru bulunamadı.", systemImage: "questionmark.circle")
                    .font(.caption).foregroundStyle(.secondary)
            }

            if let vehicle {
                investmentReport(vehicle: vehicle)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Kayıtlı hasar").font(.caption2).foregroundStyle(.secondary)
                    Text(listing.recordedDamage.liraText).font(.caption.bold().monospacedDigit())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Sabit satış bedeli").font(.caption2).foregroundStyle(.secondary)
                    Text(listing.fixedPrice.liraText)
                        .font(.title3.bold().monospacedDigit()).foregroundStyle(GarageStyle.mint)
                }
            }

            Text("İnceleme bulma olasılığını yükseltir fakat bütün gizli kusurları garanti etmez. Satın alma sonrası sökümde yeni işler çıkabilir.")
                .font(.caption2).foregroundStyle(.secondary)

            Button(action: purchase) {
                Label(listing.severity == .heavy ? "Hasarlı Aracı Satın Al" : "Hurda Araç Satın Alınamaz", systemImage: "cart.fill")
            }
            .buttonStyle(ActionButtonStyle(tint: GarageStyle.mint))
            .disabled(listing.severity != .heavy)
            .id("purchase")
        }
        .garageCard()
        .padding(.horizontal, 12)
    }

    private var inspectionControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("USTANIN İNCELEMESİ").font(.caption2.bold()).foregroundStyle(GarageStyle.orange)
            Text("İstediğin kontrolleri yapabilir veya mevcut bilgiyle risk alabilirsin.")
                .font(.caption2).foregroundStyle(.secondary)
            ForEach(SalvageInspectionKind.allCases, id: \.self) { kind in
                if listing.performedInspections.contains(kind) {
                    Label("\(kind.title) tamamlandı", systemImage: "checkmark.circle.fill")
                        .font(.caption.bold()).foregroundStyle(GarageStyle.mint)
                } else {
                    Button {
                        inspect(kind)
                    } label: {
                        Label("\(kind.title) • \(kind.durationMinutes) dk", systemImage: "magnifyingglass")
                    }
                    .buttonStyle(ActionButtonStyle(tint: GarageStyle.raised, foreground: .white))
                }
            }
        }
    }

    private var impactSummary: String {
        let damaged = listing.panelDamages.filter { $0.condition != .original }
        let frontPanels: Set<VehiclePanel> = [.frontBumper, .hood, .leftFrontFender, .rightFrontFender]
        let rearPanels: Set<VehiclePanel> = [.trunk, .rearBumper, .leftRearFender, .rightRearFender]
        let front = damaged.filter { frontPanels.contains($0.panel) }.count
        let rear = damaged.filter { rearPanels.contains($0.panel) }.count
        if front > rear { return "Ön bölüm darbe kaydı bulunuyor" }
        if rear > front { return "Arka bölüm darbe kaydı bulunuyor" }
        return "Yan ve çevresel kaporta hasarı bulunuyor"
    }

    private var revealedPanelDamages: [PanelDamage] {
        listing.panelDamages.filter {
            $0.condition != .original
                && VehiclePanel.exteriorCases.contains($0.panel)
                && listing.revealedPanelIDs.contains($0.panel)
        }
    }

    private func investmentReport(vehicle: VehicleDefinition) -> some View {
        let estimate = VehicleTradingRules.investmentEstimate(
            listing: listing,
            vehicle: vehicle,
            catalog: catalog,
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

    private var vehicle: VehicleDefinition? { catalog.vehicle(id: listing.vehicleID) }

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
