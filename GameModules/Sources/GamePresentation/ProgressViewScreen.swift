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
            }
            .padding(.vertical, 8)
        }
    }

    private func customerName(_ id: String) -> String {
        store.catalog.customer(id: id)?.name ?? "Müşteri"
    }
}
