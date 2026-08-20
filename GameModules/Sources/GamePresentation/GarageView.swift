import GameDomain
import GameLogic
import SwiftUI

struct GarageView: View {
    @ObservedObject var store: GameStore
    @State private var visiblePage = 0
    @State private var miniGame: GarageMiniGameRequest?

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                statusBar
                content
            }

            if let miniGame {
                miniGameOverlay(miniGame)
            }
        }
        .animation(.spring(response: 0.3), value: miniGame?.id)
        .onChange(of: store.state.revision) { _, _ in
            visiblePage = min(visiblePage, max(0, projects.count - 1))
        }
    }

    private var statusBar: some View {
        HStack(spacing: 10) {
            Label("Garaj \(projects.count)/\(garageCapacity)", systemImage: "building.2.crop.circle.fill")
                .accessibilityLabel("Garajda \(projects.count) proje aracı var. Kapasite \(garageCapacity) araç.")
            Spacer()
            if projects.count > 1 {
                Label("\(visiblePage + 1)/\(projects.count) • Kaydır", systemImage: "arrow.left.and.right")
                    .accessibilityLabel("Proje aracı \(visiblePage + 1) / \(projects.count), yana kaydır")
            }
        }
        .font(.caption.bold().monospacedDigit())
        .padding(.horizontal, 16)
        .frame(height: 42)
        .background(.black.opacity(0.72))
    }

    @ViewBuilder
    private var content: some View {
        if garageCapacity == 0 {
            unavailableCard
        } else if projects.isEmpty {
            emptyGarageCard
        } else {
            projectPager
        }
    }

    private var unavailableCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.fill")
                .font(.system(size: 38))
                .foregroundStyle(GarageStyle.orange)
            Text("Garaj Henüz Açılmadı")
                .font(.title3.bold())
            Text("Dükkânı Seviye 2'ye geliştirince ilk proje aracı yeri açılır. Sonraki gelişimler Garaj kapasitesini dört araca kadar yükseltir.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(28)
        .accessibilityElement(children: .combine)
    }

    private var emptyGarageCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "car.side.rear.open.fill")
                .font(.system(size: 42))
                .foregroundStyle(GarageStyle.orange)
            Text("Garaj Boş")
                .font(.title3.bold())
            Text("Hasarlı bölümünden aldığın araç burada görünür. Proje araçları müşteri liftlerini işgal etmez.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(28)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var projectPager: some View {
        #if os(iOS)
        pager.tabViewStyle(.page(indexDisplayMode: projects.count > 1 ? .always : .never))
        #else
        pager
        #endif
    }

    private var pager: some View {
        TabView(selection: $visiblePage) {
            ForEach(Array(projects.enumerated()), id: \.element.id) { index, project in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        projectHeader(project)
                        projectContent(project)
                    }
                    .padding(.top, 12)
                    .padding(.bottom, projects.count > 1 ? 36 : 20)
                }
                .tag(index)
            }
        }
    }

    private func projectHeader(_ project: ProjectCar) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(store.catalog.vehicle(id: project.vehicleID)?.name ?? "Proje Araç")
                        .font(.title3.bold())
                    Text(project.stage.garageTitle)
                        .font(.caption.bold())
                        .foregroundStyle(project.stage == .listed ? GarageStyle.mint : GarageStyle.orange)
                }
                Spacer()
                Text(project.purchasePrice.liraText)
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Label("Hasarlı'dan geliş sırasına göre Garaj'da tutuluyor", systemImage: "arrow.right.circle.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .garageCard()
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    private func projectContent(_ project: ProjectCar) -> some View {
        if project.stage == .listed {
            VStack(alignment: .leading, spacing: 9) {
                Label("Araç ilanda", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(GarageStyle.mint)
                Text("İlan fiyatını, gelen teklifleri ve pazarlığı İlanlar bölümünden yönetebilirsin. Araç satılana kadar Garaj yerini kullanır.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .garageCard()
            .padding(.horizontal, 12)
        } else {
            ProjectRestorationCard(
                project: project,
                catalog: store.catalog,
                hasBodyPaintBooth: currentFacilities.contains(.bodyPaintBooth)
            ) { task, title, kind in
                miniGame = GarageMiniGameRequest(
                    projectID: project.id,
                    task: task,
                    title: title,
                    kind: kind
                )
            }
            if project.stage == .readyForSale {
                Text("Zorunlu işler tamamlandı. Yıpranmış parçaları istersen yenile; hazır olduğunda İlanlar bölümünden satışa çıkar.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .garageCard()
                    .padding(.horizontal, 12)
            }
        }
    }

    private func miniGameOverlay(_ request: GarageMiniGameRequest) -> some View {
        ZStack {
            Color.black.opacity(0.82).ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Text(request.title).font(.headline)
                    Spacer()
                    Button {
                        miniGame = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill").font(.title2)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Restorasyon oyununu kapat")
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)

                RepairMiniGameHost(
                    kind: request.kind,
                    partName: request.title,
                    challengeKey: "\(request.projectID.uuidString)-\(request.title)"
                ) { score in
                    miniGame = nil
                    store.send(.completeProjectRepair(
                        projectID: request.projectID,
                        task: request.task,
                        performance: score
                    ))
                }
            }
            .background(GarageStyle.background)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(12)
        }
        .transition(.scale.combined(with: .opacity))
        .zIndex(10)
    }

    private var projects: [ProjectCar] {
        store.state.projectCars.sorted { $0.purchasedAtMinute < $1.purchasedAtMinute }
    }

    private var garageCapacity: Int {
        store.catalog.shopLevel(store.state.shopLevel)?.garageCapacity ?? 0
    }

    private var currentFacilities: [ShopFacility] {
        store.catalog.shopLevel(store.state.shopLevel)?.facilities ?? []
    }
}

private struct GarageMiniGameRequest: Identifiable, Equatable {
    let id = UUID()
    let projectID: UUID
    let task: ProjectRepairTask
    let title: String
    let kind: RepairGameKind
}

private extension ProjectCarStage {
    var garageTitle: String {
        switch self {
        case .awaitingRepair: "Restorasyon bekliyor"
        case .readyForSale: "Satışa hazır"
        case .listed: "İlanda"
        }
    }
}
