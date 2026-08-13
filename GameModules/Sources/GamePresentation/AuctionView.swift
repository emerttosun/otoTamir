import GameDomain
import SwiftUI

struct AuctionView: View {
    @ObservedObject var store: GameStore

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if let auction = store.state.auction {
                    auctionHeader(auction)
                    ForEach(auction.lots) { lot in
                        AuctionLotCard(lot: lot, catalog: store.catalog) { command in
                            store.send(command)
                        }
                    }
                    Button(auction.round == 3 ? "İhaleyi Sonuçlandır" : "\(auction.round + 1). Tura Geç") {
                        store.send(.advanceAuctionRound)
                    }
                    .buttonStyle(ActionButtonStyle(tint: GarageStyle.mint))
                    .padding(.horizontal, 12)
                } else {
                    VStack(spacing: 14) {
                        Image(systemName: "gavel.fill")
                            .font(.system(size: 46))
                            .foregroundStyle(GarageStyle.orange)
                        Text(store.state.day < 4 ? "İhale 4. gün açılır" : "Bugün ihale yok")
                            .font(.title3.bold())
                        Text("Sanayi ihalesi üç günde bir kurulur. Ekspertiz gizli kusurların bir kısmını gösterir; dükkânda yer bırakmayı unutma.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .garageCard()
                    .padding(.horizontal, 12)
                    .padding(.top, 18)
                }

                if !store.state.projectCars.isEmpty {
                    Label("Proje Araçlar", systemImage: "car.rear.road.lane")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    ForEach(store.state.projectCars) { project in
                        ProjectCarCard(project: project, catalog: store.catalog) { command in
                            store.send(command)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func auctionHeader(_ auction: AuctionState) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("SANAYİ İHALESİ").font(.caption.weight(.black)).foregroundStyle(GarageStyle.orange)
                Text("Tur \(auction.round) / 3").font(.title3.bold())
            }
            Spacer()
            Text("Tek araca odaklan")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .garageCard()
        .padding(.horizontal, 12)
    }
}

private struct AuctionLotCard: View {
    let lot: AuctionLot
    let catalog: ContentCatalog
    let send: (GameCommand) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                VStack(alignment: .leading) {
                    Text(vehicle?.name ?? "Kazalı Araç").font(.headline)
                    Text(vehicle?.category ?? "").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if lot.playerIsHighest {
                    Label("Lider", systemImage: "flag.fill")
                        .font(.caption.bold())
                        .foregroundStyle(GarageStyle.mint)
                }
            }

            faultRow(title: "Görünen", ids: [lot.visibleFaultID])
            if !lot.revealedFaultIDs.isEmpty {
                faultRow(title: "Ekspertiz", ids: lot.revealedFaultIDs)
            } else {
                Text("Gizli kusur ihtimali var")
                    .font(.caption)
                    .foregroundStyle(GarageStyle.danger)
            }

            HStack {
                VStack(alignment: .leading) {
                    Text("Güncel teklif").font(.caption).foregroundStyle(.secondary)
                    Text(lot.currentBid.liraText).font(.title3.bold().monospacedDigit())
                }
                Spacer()
                Text(competitorMood)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(GarageStyle.orange)
            }

            HStack(spacing: 8) {
                Button("Ekspertiz") { send(.inspectAuctionLot(lot.id)) }
                    .buttonStyle(ActionButtonStyle(tint: GarageStyle.raised))
                    .foregroundStyle(.white)
                Button("+500 ₺") { send(.placeAuctionBid(lotID: lot.id, amount: lot.currentBid + Money(minorUnits: 50_000))) }
                    .buttonStyle(ActionButtonStyle())
                Button("+1.500 ₺") { send(.placeAuctionBid(lotID: lot.id, amount: lot.currentBid + Money(minorUnits: 150_000))) }
                    .buttonStyle(ActionButtonStyle(tint: GarageStyle.mint))
            }
        }
        .garageCard()
        .padding(.horizontal, 12)
    }

    private func faultRow(title: String, ids: [String]) -> some View {
        HStack(alignment: .top) {
            Text("\(title):").font(.caption.bold()).frame(width: 62, alignment: .leading)
            Text(ids.compactMap { catalog.fault(id: $0)?.name }.joined(separator: ", "))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    private var competitorMood: String {
        let ratio = Double(lot.currentBid.minorUnits) / Double(max(1, lot.competitorMaximum.minorUnits))
        if ratio < 0.65 { return "Rakip rahat" }
        if ratio < 0.9 { return "Rakip düşünüyor" }
        return "Rakip çekilebilir"
    }

    private var vehicle: VehicleDefinition? { catalog.vehicle(id: lot.vehicleID) }
}

private struct ProjectCarCard: View {
    let project: ProjectCar
    let catalog: ContentCatalog
    let send: (GameCommand) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                VStack(alignment: .leading) {
                    Text(vehicle?.name ?? "Proje Araç").font(.headline)
                    Text("Alış: \(project.purchasePrice.liraText)").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(project.stage == .awaitingRepair ? "RESTORASYON" : "SATIŞA HAZIR")
                    .font(.caption2.bold())
                    .foregroundStyle(project.stage == .awaitingRepair ? GarageStyle.orange : GarageStyle.mint)
            }

            Text("Kusurlar: \(faultNames)")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))

            if project.stage == .awaitingRepair {
                Text("Restorasyon 3 zaman dilimi harcar ve tüm parçaları birlikte yeniler.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Button("Restorasyonu Yap") {
                    send(.repairProjectCar(projectID: project.id, performance: 74))
                }
                .buttonStyle(ActionButtonStyle(tint: GarageStyle.mint))
            } else {
                Text("Restorasyon kalitesi: %\(project.restorationQuality)")
                    .font(.caption.weight(.semibold))
                HStack(spacing: 8) {
                    Button("Kusurları Anlat") { send(.sellProjectCar(projectID: project.id, honest: true)) }
                        .buttonStyle(ActionButtonStyle(tint: GarageStyle.mint))
                    Button("Parlat, Gönder") { send(.sellProjectCar(projectID: project.id, honest: false)) }
                        .buttonStyle(ActionButtonStyle(tint: GarageStyle.danger))
                }
            }
        }
        .garageCard()
        .padding(.horizontal, 12)
    }

    private var vehicle: VehicleDefinition? { catalog.vehicle(id: project.vehicleID) }
    private var faultNames: String {
        project.faultIDs.compactMap { catalog.fault(id: $0)?.name }.joined(separator: ", ")
    }
}

