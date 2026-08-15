import GameDomain
import GameLogic
import SwiftUI

struct ProjectCarCard: View {
    let project: ProjectCar
    let catalog: ContentCatalog
    let ratingTenths: Int
    let hasShowroom: Bool
    let hasBodyPaintBooth: Bool
    let send: (GameCommand) -> Void
    @State private var askingPercent = 100.0
    @State private var discloseDamage = true

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                VStack(alignment: .leading) {
                    Text(vehicle?.name ?? "Proje Araç").font(.headline)
                    Text("İhaleden alış: \(project.purchasePrice.liraText)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(stageTitle)
                    .font(.caption2.bold())
                    .foregroundStyle(project.stage == .awaitingRepair ? GarageStyle.orange : GarageStyle.mint)
            }

            Text("\(project.stage == .awaitingRepair ? "Onarılacaklar" : "Onarılanlar"): \(faultNames)")
                .font(.caption).foregroundStyle(.white.opacity(0.8))

            if project.stage == .readyForSale, let vehicle {
                listingForm(vehicle: vehicle)
            } else if project.stage == .listed, let vehicle, let price = project.askingPrice {
                listedContent(vehicle: vehicle, price: price)
            }
        }
        .garageCard()
        .padding(.horizontal, 12)
    }

    private func listingForm(vehicle: VehicleDefinition) -> some View {
        let price = askingPrice(vehicle: vehicle)
        let estimate = listingEstimate(vehicle: vehicle, price: price)
        return VStack(alignment: .leading, spacing: 9) {
            Text("Restorasyon kalitesi: %\(project.restorationQuality)")
                .font(.caption.weight(.semibold))
            RestoredBodyHistoryView(project: project)
            Text("İLAN HAZIRLA")
                .font(.caption2.bold()).foregroundStyle(GarageStyle.orange)
            HStack {
                Text("Adil fiyat önerisi")
                Spacer()
                Text("\(estimate.recommendedLow.liraText) – \(estimate.recommendedHigh.liraText)")
                    .bold().monospacedDigit()
            }
            .font(.caption)
            Slider(value: $askingPercent, in: 80...145, step: 5)
                .tint(GarageStyle.orange)
                .accessibilityLabel("İlan fiyatı oranı")
            HStack {
                Text("İlan fiyatı: \(price.liraText)").bold()
                Spacer()
                Text("Satış ihtimali: %\(estimate.saleChancePercent)")
                    .foregroundStyle(chanceColor(estimate.saleChancePercent))
            }
            .font(.caption.monospacedDigit())
            Toggle("Ağır hasar geçmişini ilanda açıkla", isOn: $discloseDamage)
                .font(.caption)
            Text("İlan bedeli: \(VehicleTradingRules.listingFee.liraText)")
                .font(.caption2).foregroundStyle(.secondary)
            Button("İlanı Yayınla") {
                send(.listProjectCar(
                    projectID: project.id,
                    askingPrice: price,
                    discloseDamage: discloseDamage
                ))
            }
            .buttonStyle(ActionButtonStyle(tint: GarageStyle.mint))
        }
    }

    private func listedContent(vehicle: VehicleDefinition, price: Money) -> some View {
        let estimate = VehicleTradingRules.listingEstimate(
            project: project,
            vehicle: vehicle,
            askingPrice: price,
            ratingTenths: ratingTenths,
            hasShowroom: hasShowroom,
            discloseDamage: project.disclosedDamage
        )
        return VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label("Yayında", systemImage: "checkmark.circle.fill")
                    .font(.caption.bold()).foregroundStyle(GarageStyle.mint)
                Spacer()
                Text("%\(estimate.saleChancePercent) alıcı ihtimali")
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(chanceColor(estimate.saleChancePercent))
            }
            Text("İlan fiyatı: \(price.liraText)")
                .font(.headline.monospacedDigit())
            Text(project.disclosedDamage
                 ? "Ağır hasar geçmişi ilanda açıklandı."
                 : "Ağır hasar geçmişi saklandı; satış sonrası şikâyet riski var.")
                .font(.caption2)
                .foregroundStyle(project.disclosedDamage ? GarageStyle.mint : GarageStyle.danger)
            RestoredBodyHistoryView(project: project)
            Divider().overlay(.white.opacity(0.12))
            Text("ALICI TEKLİFLERİ")
                .font(.caption2.weight(.black))
                .foregroundStyle(GarageStyle.orange)
            if project.buyerOffers.isEmpty {
                Text("Henüz ciddi teklif yok. Aşağıdaki düğmeyle yeni alıcıları kontrol edebilirsin.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(project.buyerOffers) { offer in
                    VehicleBuyerOfferCard(
                        projectID: project.id,
                        askingPrice: price,
                        offer: offer,
                        send: send
                    )
                }
            }
            Button("İlanı Geri Çek") {
                send(.cancelProjectListing(projectID: project.id))
            }
            .buttonStyle(ActionButtonStyle(tint: GarageStyle.raised, foreground: .white))
        }
    }

    private var vehicle: VehicleDefinition? { catalog.vehicle(id: project.vehicleID) }

    private var stageTitle: String {
        switch project.stage {
        case .awaitingRepair: "RESTORASYON"
        case .readyForSale: "SATIŞA HAZIR"
        case .listed: "İLANDA"
        }
    }

    private func askingPrice(vehicle: VehicleDefinition) -> Money {
        let fair = VehicleTradingRules.fairPrice(project: project, vehicle: vehicle)
        return Money(minorUnits: fair.minorUnits * Int64(askingPercent) / 100)
    }

    private func listingEstimate(vehicle: VehicleDefinition, price: Money) -> VehicleListingEstimate {
        VehicleTradingRules.listingEstimate(
            project: project,
            vehicle: vehicle,
            askingPrice: price,
            ratingTenths: ratingTenths,
            hasShowroom: hasShowroom,
            discloseDamage: discloseDamage
        )
    }

    private func chanceColor(_ chance: Int) -> Color {
        chance >= 65 ? GarageStyle.mint : (chance >= 35 ? GarageStyle.orange : GarageStyle.danger)
    }

    private var faultNames: String {
        project.faultIDs.compactMap { catalog.fault(id: $0)?.name }.joined(separator: ", ")
    }
}
