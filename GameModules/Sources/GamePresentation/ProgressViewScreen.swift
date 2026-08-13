import GameDomain
import SwiftUI

struct ProgressViewScreen: View {
    @ObservedObject var store: GameStore

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                reputationCard
                skillsCard
                shopCard
                cloudCard
                storeCard
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private var reputationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Esnaf Karnesi", systemImage: "person.text.rectangle.fill").font(.headline)
            metric("Ustalık şöhreti", value: store.state.reputation.craftsmanship, tint: GarageStyle.mint)
            metric("Müşteri güveni", value: store.state.reputation.trust, tint: .blue)
            metric("Şaibe", value: store.state.reputation.suspicion, tint: GarageStyle.danger)
        }
        .garageCard()
    }

    private var skillsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Uzmanlıklar", systemImage: "graduationcap.fill").font(.headline)
            ForEach(SkillArea.allCases, id: \.self) { skill in
                HStack {
                    Text(skill.title).font(.subheadline)
                    Spacer()
                    Text("Seviye \(store.state.skills[skill, default: 1])")
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(GarageStyle.orange)
                }
            }
        }
        .garageCard()
    }

    private var shopCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Dükkân", systemImage: "building.2.fill").font(.headline)
            if let current = store.catalog.shopLevel(store.state.shopLevel) {
                Text(current.name).font(.title3.bold())
                Text("\(current.capacity) araç kapasitesi • +\(current.equipmentBonus) ekipman katkısı")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let next = store.catalog.shopLevel(store.state.shopLevel + 1) {
                Button("\(next.name) • \(next.upgradeCost.liraText)") {
                    store.send(.upgradeShop)
                }
                .buttonStyle(ActionButtonStyle())
            } else {
                Label("En yüksek dükkân seviyesindesin", systemImage: "checkmark.seal.fill")
                    .font(.subheadline).foregroundStyle(GarageStyle.mint)
            }
        }
        .garageCard()
    }

    private var cloudCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Kayıt", systemImage: "icloud.fill").font(.headline)
            Text("Her işlem cihazda kaydedilir. iCloud kapalıysa oyun kesintisiz yerel devam eder.")
                .font(.caption).foregroundStyle(.secondary)
            Button("iCloud ile Eşitle") {
                Task { await store.synchronizeCloud() }
            }
            .buttonStyle(ActionButtonStyle(tint: .blue))
        }
        .garageCard()
    }

    private var storeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Dükkân Mağazası", systemImage: "bag.fill").font(.headline)
            Text("Paketler yalnızca hızlandırır; ustalık, güven ve iyi işçilik satın alınamaz.")
                .font(.caption).foregroundStyle(.secondary)
            if store.products.isEmpty {
                Text("StoreKit test ürünleri yüklenmedi. Oyun içi ilerleme etkilenmez.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(store.products) { product in
                    Button {
                        Task { await store.purchase(product) }
                    } label: {
                        HStack {
                            Text(product.displayName)
                            Spacer()
                            Text(product.displayPrice)
                        }
                    }
                    .buttonStyle(ActionButtonStyle(tint: GarageStyle.orange))
                }
                Button("Satın Almaları Geri Yükle") {
                    Task { await store.restorePurchases() }
                }
                .font(.caption.bold())
                .foregroundStyle(GarageStyle.orange)
            }
        }
        .garageCard()
    }

    private func metric(_ title: String, value: Int, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title).font(.caption)
                Spacer()
                Text("%\(value)").font(.caption.bold().monospacedDigit())
            }
            SwiftUI.ProgressView(value: Double(value), total: 100).tint(tint)
        }
    }
}
