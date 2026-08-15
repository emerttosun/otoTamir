import GameDomain
import SwiftUI

struct ShopStoreView: View {
    @ObservedObject var store: GameStore

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                header
                cashProducts
                otherProducts
                restoreCard
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label("DÜKKÂN MAĞAZASI", systemImage: "bag.fill")
                .font(.caption.weight(.black)).foregroundStyle(GarageStyle.orange)
            Text("Ustanın kasasını destekle").font(.title3.bold())
            Text("Gerçek para ile alınan kasa paketleri yalnız ilerlemeyi hızlandırır. İyi işçilik, uzmanlık, güven ve ihale sonucu satın alınamaz.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .garageCard()
    }

    private var cashProducts: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Oyun Parası", systemImage: "turkishlirasign.circle.fill").font(.headline)
            if cashPackages.isEmpty {
                Text("Kasa paketleri StoreKit test mağazasından yükleniyor. Canlı satışlar App Store Connect ürünleri onaylandığında çalışır.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(cashPackages) { product in
                    productButton(product, tint: GarageStyle.mint)
                }
            }
        }
        .garageCard()
    }

    private var otherProducts: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Kozmetik ve İçerik", systemImage: "paintpalette.fill").font(.headline)
            if nonCashProducts.isEmpty {
                Text("Şu anda kullanılabilir kozmetik veya içerik paketi yok.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(nonCashProducts) { product in
                    productButton(product, tint: GarageStyle.orange)
                }
            }
        }
        .garageCard()
    }

    private var restoreCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Kozmetik ve içerik paketleri geri yüklenebilir. Harcanabilir oyun parası paketleri geri yüklenmez.")
                .font(.caption).foregroundStyle(.secondary)
            Button("Satın Almaları Geri Yükle") {
                Task { await store.restorePurchases() }
            }
            .buttonStyle(ActionButtonStyle(tint: GarageStyle.raised, foreground: .white))
        }
        .garageCard()
    }

    private func productButton(_ product: CommerceProduct, tint: Color) -> some View {
        Button {
            Task { await store.purchase(product) }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(product.displayName).font(.subheadline.bold())
                    Text(product.id.contains(".cash.") ? cashReward(for: product.id) : "Tek seferlik satın alma")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Text(product.displayPrice).font(.subheadline.bold())
            }
        }
        .buttonStyle(ActionButtonStyle(tint: tint))
        .accessibilityHint("Gerçek para ile satın alma ekranını açar")
    }

    private var cashPackages: [CommerceProduct] {
        store.products.filter { $0.id.contains(".cash.") }
    }

    private var nonCashProducts: [CommerceProduct] {
        store.products.filter { !$0.id.contains(".cash.") }
    }

    private func cashReward(for productID: String) -> String {
        productID.hasSuffix("cash.small") ? "Dükkân kasasına 7.500 ₺" : "Dükkân kasasına 25.000 ₺"
    }
}
