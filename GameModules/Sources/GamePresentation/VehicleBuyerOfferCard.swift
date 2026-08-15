import GameDomain
import SwiftUI

struct VehicleBuyerOfferCard: View {
    let projectID: UUID
    let askingPrice: Money
    let offer: VehicleBuyerOffer
    let send: (GameCommand) -> Void

    @State private var isNegotiating = false
    @State private var counterMinorUnits: Double

    init(
        projectID: UUID,
        askingPrice: Money,
        offer: VehicleBuyerOffer,
        send: @escaping (GameCommand) -> Void
    ) {
        self.projectID = projectID
        self.askingPrice = askingPrice
        self.offer = offer
        self.send = send
        let suggested = min(
            askingPrice.minorUnits,
            max(offer.amount.minorUnits + 100_000, offer.amount.minorUnits * 103 / 100)
        )
        _counterMinorUnits = State(initialValue: Double(suggested))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(offer.buyerName).font(.caption.weight(.bold))
                    Text(offer.negotiationCount == 0 ? "Yeni alıcı teklifi" : "Pazarlıktan dönen teklif")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Text(offer.amount.liraText)
                    .font(.caption.weight(.black).monospacedDigit())
                    .foregroundStyle(GarageStyle.mint)
            }

            if isNegotiating {
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text("Karşı teklif")
                        Spacer()
                        Text(counterOffer.liraText).bold().monospacedDigit()
                    }
                    .font(.caption)
                    Slider(
                        value: $counterMinorUnits,
                        in: Double(minimumCounter.minorUnits)...Double(askingPrice.minorUnits),
                        step: 100_000
                    )
                    .tint(GarageStyle.orange)
                    .accessibilityLabel("Alıcıya karşı teklif")
                    Button("Karşı Teklifi Gönder") {
                        send(.negotiateVehicleOffer(
                            projectID: projectID,
                            offerID: offer.id,
                            counterOffer: counterOffer
                        ))
                        isNegotiating = false
                    }
                    .buttonStyle(ActionButtonStyle(tint: GarageStyle.orange))
                }
            }

            HStack(spacing: 8) {
                Button("Reddet") {
                    send(.rejectVehicleOffer(projectID: projectID, offerID: offer.id))
                }
                .buttonStyle(ActionButtonStyle(tint: GarageStyle.raised, foreground: .white))

                Button(isNegotiating ? "Vazgeç" : "Pazarlık") {
                    isNegotiating.toggle()
                }
                .buttonStyle(ActionButtonStyle(tint: GarageStyle.orange))

                Button("Kabul Et") {
                    send(.acceptVehicleOffer(projectID: projectID, offerID: offer.id))
                }
                .buttonStyle(ActionButtonStyle(tint: GarageStyle.mint))
            }
            .font(.caption.bold())
        }
        .padding(10)
        .background(.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .contain)
    }

    private var minimumCounter: Money {
        Money(minorUnits: min(askingPrice.minorUnits, offer.amount.minorUnits + 100_000))
    }

    private var counterOffer: Money {
        Money(minorUnits: Int64(counterMinorUnits))
    }
}
