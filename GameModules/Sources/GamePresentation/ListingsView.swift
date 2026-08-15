import GameDomain
import SwiftUI

struct ListingsView: View {
    @ObservedObject var store: GameStore

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                header

                if saleProjects.isEmpty {
                    emptyState
                } else {
                    ForEach(saleProjects) { project in
                        ProjectCarCard(
                            project: project,
                            catalog: store.catalog,
                            ratingTenths: store.state.ratingTenths,
                            hasShowroom: currentFacilities.contains(.vehicleShowroom),
                            hasBodyPaintBooth: currentFacilities.contains(.bodyPaintBooth)
                        ) { command in
                            store.send(command)
                        }
                    }

                    if saleProjects.contains(where: { $0.stage == .listed }) {
                        Button {
                            store.send(.checkVehicleListings)
                        } label: {
                            Label("İlanlardaki Alıcıları Kontrol Et", systemImage: "arrow.clockwise.circle.fill")
                        }
                        .buttonStyle(ActionButtonStyle(tint: GarageStyle.orange))
                        .padding(.horizontal, 12)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("USTANIN İLAN YERİ")
                .font(.caption.weight(.black)).foregroundStyle(GarageStyle.orange)
            Text("Satışa hazır araçlar").font(.title3.bold())
            Text("Restorasyonu biten araca fiyat biç, ağır hasar bilgisini açıklayıp açıklamayacağını seç ve alıcıları takip et.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .garageCard()
        .padding(.horizontal, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 13) {
            Image(systemName: "rectangle.and.pencil.and.ellipsis")
                .font(.system(size: 42))
                .foregroundStyle(GarageStyle.orange)
            Text("İlana konacak araç yok").font(.headline)
            Text("İhaleden aldığın aracı restore edince burada satışa çıkarabilirsin.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .garageCard()
        .padding(.horizontal, 12)
    }

    private var saleProjects: [ProjectCar] {
        store.state.projectCars.filter { $0.stage != .awaitingRepair }
    }

    private var currentFacilities: [ShopFacility] {
        store.catalog.shopLevel(store.state.shopLevel)?.facilities ?? []
    }
}
