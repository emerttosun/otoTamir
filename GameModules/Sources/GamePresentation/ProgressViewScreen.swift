import GameDomain
import SwiftUI

struct ProgressViewScreen: View {
    @ObservedObject var store: GameStore

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                WorkshopDevelopmentView(store: store)

                VStack(alignment: .leading, spacing: 11) {
                    HStack {
                        Label("Müşteri Yorumları", systemImage: "text.bubble.fill").font(.headline)
                        Spacer()
                        Text("★ \(store.state.shopRatingText)")
                            .font(.headline.monospacedDigit()).foregroundStyle(GarageStyle.orange)
                    }
                    if store.state.reviews.isEmpty {
                        Text("Henüz yorum yok. Teslim edilen işler burada görünecek.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    } else {
                        ForEach(store.state.reviews.reversed()) { review in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(customerName(review.customerID)).font(.subheadline.bold())
                                    Spacer()
                                    Text(String(repeating: "★", count: review.stars))
                                        .font(.caption).foregroundStyle(GarageStyle.orange)
                                }
                                Text(review.text).font(.caption)
                                Text("Gün \(review.day)").font(.caption2).foregroundStyle(.secondary)
                            }
                            .padding(10)
                            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 11))
                        }
                    }
                }
                .garageCard()
                .padding(.horizontal, 12)

                incidentLedger
            }
            .padding(.vertical, 8)
        }
    }

    private func customerName(_ id: String) -> String {
        store.catalog.customer(id: id)?.name ?? "Müşteri"
    }

    private var incidentLedger: some View {
        VStack(alignment: .leading, spacing: 11) {
            Label("Olay Defteri", systemImage: "books.vertical.fill")
                .font(.headline)
            Text("Denetim, geri dönüş, kredi ve araç satışı sonuçları burada kalıcı olarak tutulur.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if store.state.incidents.isEmpty {
                Text("Henüz kayıtlı bir dükkân olayı yok.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.state.incidents.reversed()) { incident in
                    incidentRow(incident)
                }
            }
        }
        .garageCard()
        .padding(.horizontal, 12)
    }

    private func incidentRow(_ incident: GameIncident) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(incident.kind.title, systemImage: incident.kind.systemImage)
                    .font(.subheadline.bold())
                Spacer()
                Text("#\(incident.sequence)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Text(incident.message).font(.caption)
            impactRow(incident)
        }
        .padding(10)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 11))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func impactRow(_ incident: GameIncident) -> some View {
        let impacts = [
            incident.cashImpact == .zero ? nil : "Kasa \(signedMoney(incident.cashImpact))",
            incident.trustImpact == 0 ? nil : "Güven \(signed(incident.trustImpact))",
            incident.craftsmanshipImpact == 0 ? nil : "Ustalık \(signed(incident.craftsmanshipImpact))",
            incident.suspicionImpact == 0 ? nil : "Şaibe \(signed(incident.suspicionImpact))"
        ].compactMap { $0 }

        if !impacts.isEmpty {
            Text(impacts.joined(separator: " • "))
                .font(.caption2.bold())
                .foregroundStyle(incident.cashImpact.minorUnits < 0 ? GarageStyle.danger : GarageStyle.mint)
        }
    }

    private func signed(_ value: Int) -> String { value > 0 ? "+\(value)" : "\(value)" }

    private func signedMoney(_ value: Money) -> String {
        value.minorUnits > 0 ? "+\(value.liraText)" : value.liraText
    }
}
