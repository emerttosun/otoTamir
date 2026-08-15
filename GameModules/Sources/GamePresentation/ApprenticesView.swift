import GameDomain
import SwiftUI

struct ApprenticesView: View {
    @ObservedObject var store: GameStore

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                header
                roster
                hireCard
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("USTA–ÇIRAK TEZGÂHI")
                .font(.caption.weight(.black)).foregroundStyle(GarageStyle.orange)
            Text("Çırakların").font(.title3.bold())
            Text("Çıraklara müşteri aracındaki tamir veya bakım adımlarından iş ver. Çalıştıkça deneyim ve seviye kazanırlar.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .garageCard()
    }

    private var roster: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Kadro", systemImage: "person.2.fill").font(.headline)
            if store.state.apprentices.isEmpty {
                Text("Henüz yanında çalışan çırak yok.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(store.state.apprentices) { apprentice in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            ZStack {
                                Circle().fill(GarageStyle.orange.opacity(0.18)).frame(width: 42, height: 42)
                                Image(systemName: "person.fill").foregroundStyle(GarageStyle.orange)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(apprentice.name).font(.subheadline.bold())
                                Text("Seviye \(apprentice.level)")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(apprentice.experience)/\(apprentice.level * 100) XP")
                                .font(.caption2.bold().monospacedDigit())
                        }
                        SwiftUI.ProgressView(
                            value: Double(apprentice.experience),
                            total: Double(apprentice.level * 100)
                        )
                        .tint(GarageStyle.orange)
                    }
                    .padding(10)
                    .background(GarageStyle.raised.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .garageCard()
    }

    private var hireCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label("Yeni Çırak", systemImage: "person.badge.plus").font(.headline)
            if let shop = store.catalog.shopLevel(store.state.shopLevel),
               shop.facilities.contains(.apprenticeStation),
               store.state.apprentices.count < shop.maxApprentices {
                Text("Boş çırak yeri: \(shop.maxApprentices - store.state.apprentices.count)")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Çırak Al • \(store.catalog.balance.apprenticeHireCost.liraText)") {
                    store.send(.hireApprentice)
                }
                .buttonStyle(ActionButtonStyle(tint: GarageStyle.orange))
                Text("Günlük ücret: kişi başı \(store.catalog.balance.apprenticeDailyWage.liraText)")
                    .font(.caption2).foregroundStyle(.secondary)
            } else if store.catalog.shopLevel(store.state.shopLevel)?.facilities.contains(.apprenticeStation) != true {
                Label("Çırak tezgâhı Dükkân Gelişimi ile açılır", systemImage: "lock.fill")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Label("Bütün çırak yerleri dolu", systemImage: "checkmark.circle.fill")
                    .font(.caption).foregroundStyle(GarageStyle.mint)
            }
        }
        .garageCard()
    }
}
