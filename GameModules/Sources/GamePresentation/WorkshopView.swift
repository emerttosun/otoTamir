import GameDomain
import Foundation
import SwiftUI

struct WorkshopView: View {
    @ObservedObject var store: GameStore
    @State private var miniGame: MiniGameRequest?
    @State private var selectedVehicle: WorkshopVehicleSelection?

    var body: some View {
        ZStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    GarageSceneView(
                        state: store.state,
                        catalog: store.catalog,
                        selection: $selectedVehicle
                    )
                        .frame(height: 285)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(.white.opacity(0.12), lineWidth: 1)
                        }
                        .padding(.horizontal, 12)

                    sectionTitle("Seçili Araç", icon: "hand.tap.fill")
                    if let selectedJob {
                        JobCard(
                            job: selectedJob,
                            shopLevel: store.state.shopLevel,
                            washLevel: store.state.washLevel,
                            apprentices: store.state.apprentices,
                            catalog: store.catalog
                        ) { command in
                            store.send(command)
                        } startMiniGame: { request in
                            miniGame = request
                        }
                    } else if let selectedProject {
                        selectedProjectContent(selectedProject)
                    } else {
                        emptyCard(store.state.activeJobs.isEmpty && store.state.projectCars.isEmpty
                                  ? "Dükkânda araç yok. Bekleyen müşteriden araç kabul edebilir veya ihaleden proje aracı alabilirsin."
                                  : "İşlem yapmak için tamirhane görselindeki bir araca dokun.")
                    }

                    sectionTitle("Bekleyen Müşteriler", icon: "person.3.fill")
                    if store.state.offers.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Şu anda kapıda bekleyen müşteri yok.")
                                .font(.subheadline).foregroundStyle(.secondary)
                            Button("Biraz Müşteri Bekle") {
                                store.send(.advanceTime(minutes: 30))
                            }
                            .buttonStyle(ActionButtonStyle(tint: GarageStyle.raised, foreground: .white))
                        }
                        .garageCard()
                        .padding(.horizontal, 12)
                    } else {
                        ForEach(store.state.offers) { offer in
                            OfferCard(
                                offer: offer,
                                catalog: store.catalog,
                                accept: { store.send(.acceptOffer(offer.id)) },
                                decline: { store.send(.declineOffer(offer.id)) }
                            )
                        }
                    }

                }
                .padding(.bottom, 22)
            }

            if let miniGame {
                Color.black.opacity(0.82).ignoresSafeArea()
                VStack(spacing: 0) {
                    HStack {
                        Text(miniGame.title).font(.headline)
                        Spacer()
                        Button {
                            closeMiniGame()
                        } label: {
                            Image(systemName: "xmark.circle.fill").font(.title2)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Tamir oyununu kapat")
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)

                    RepairMiniGameHost(
                        kind: miniGame.kind,
                        partName: miniGame.title,
                        challengeKey: "\(miniGame.jobID.uuidString)-\(miniGame.title)"
                    ) { score in
                        finishMiniGame(miniGame, score: score)
                    }
                }
                .background(GarageStyle.background)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .padding(12)
                .transition(.scale.combined(with: .opacity))
                .zIndex(10)
            }
        }
        .animation(.spring(response: 0.3), value: miniGame?.id)
        .task {
            #if DEBUG
            if ProcessInfo.processInfo.environment["OTOTAMIR_QA_SELECT_FIRST_VEHICLE"] == "1" {
                if let job = store.state.activeJobs.first {
                    selectedVehicle = .job(job.id)
                } else if let project = store.state.projectCars.first {
                    selectedVehicle = .project(project.id)
                }
            }
            #endif
            guard miniGame == nil,
                  let rawKind = ProcessInfo.processInfo.environment["OTOTAMIR_QA_MINIGAME"],
                  let kind = RepairGameKind(rawValue: rawKind),
                  let job = store.state.activeJobs.first,
                  let faultID = job.diagnosedFaultID,
                  let fault = store.catalog.fault(id: faultID) else { return }
            miniGame = MiniGameRequest(
                jobID: job.id,
                title: fault.partName,
                kind: kind,
                maintenanceTask: nil,
                projectTask: nil
            )
        }
        .onChange(of: store.state.revision) { _, _ in
            guard let selectedVehicle else { return }
            switch selectedVehicle {
            case .job(let id):
                if !store.state.activeJobs.contains(where: { $0.id == id }) {
                    self.selectedVehicle = nil
                }
            case .project(let id):
                if !store.state.projectCars.contains(where: { $0.id == id }) {
                    self.selectedVehicle = nil
                }
            }
        }
    }

    private var selectedJob: RepairJob? {
        guard case .job(let id) = selectedVehicle else { return nil }
        return store.state.activeJobs.first { $0.id == id }
    }

    private var selectedProject: ProjectCar? {
        guard case .project(let id) = selectedVehicle else { return nil }
        return store.state.projectCars.first { $0.id == id }
    }

    @ViewBuilder
    private func selectedProjectContent(_ project: ProjectCar) -> some View {
        if project.stage == .awaitingRepair {
            ProjectRestorationCard(
                project: project,
                catalog: store.catalog,
                hasBodyPaintBooth: currentFacilities.contains(.bodyPaintBooth)
            ) { task, title, kind in
                miniGame = MiniGameRequest(
                    jobID: project.id,
                    title: title,
                    kind: kind,
                    maintenanceTask: nil,
                    projectTask: task
                )
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text(store.catalog.vehicle(id: project.vehicleID)?.name ?? "Proje Araç")
                    .font(.headline)
                Label(project.stage == .listed ? "Araç ilanda" : "Restorasyon tamamlandı", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.bold()).foregroundStyle(GarageStyle.mint)
                Text("Fiyat ve alıcı işlemlerini İlanlar bölümünden yönetebilirsin.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .garageCard()
            .padding(.horizontal, 12)
        }
    }

    private var currentFacilities: [ShopFacility] {
        store.catalog.shopLevel(store.state.shopLevel)?.facilities ?? []
    }

    private func finishMiniGame(_ request: MiniGameRequest, score: Int) {
        miniGame = nil
        if let projectTask = request.projectTask {
            store.send(.completeProjectRepair(projectID: request.jobID, task: projectTask, performance: score))
        } else if let task = request.maintenanceTask {
            store.send(.completeMaintenanceTask(jobID: request.jobID, task: task, performance: score))
        } else {
            store.send(.completeRepair(jobID: request.jobID, performance: score))
        }
    }

    private func closeMiniGame() {
        miniGame = nil
    }

    private func sectionTitle(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 3)
    }

    private func emptyCard(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .garageCard()
            .padding(.horizontal, 12)
    }
}

private struct MiniGameRequest: Identifiable, Equatable {
    let id = UUID()
    let jobID: UUID
    let title: String
    let kind: RepairGameKind
    let maintenanceTask: MaintenanceTask?
    let projectTask: ProjectRepairTask?
}

private struct OfferCard: View {
    let offer: CustomerOffer
    let catalog: ContentCatalog
    let accept: () -> Void
    let decline: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(customer?.name ?? "Müşteri").font(.headline)
                    Text(customer?.archetype ?? "").font(.caption).foregroundStyle(GarageStyle.orange)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(vehicle?.name ?? "Araç").font(.caption.weight(.semibold))
                    Text(offer.serviceKind.title)
                        .font(.caption2.bold())
                        .foregroundStyle(GarageStyle.mint)
                }
            }
            Text("“\(offer.complaint)”")
                .font(.subheadline).italic().foregroundStyle(.white.opacity(0.88))
            Text(customer?.greeting ?? "").font(.caption).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Gönder", role: .destructive, action: decline).font(.caption.bold())
                Button("Aracı Kabul Et", action: accept).buttonStyle(ActionButtonStyle())
            }
        }
        .garageCard()
        .padding(.horizontal, 12)
        .accessibilityElement(children: .contain)
    }

    private var customer: CustomerDefinition? { catalog.customer(id: offer.customerID) }
    private var vehicle: VehicleDefinition? { catalog.vehicle(id: offer.vehicleID) }
}

private struct JobCard: View {
    let job: RepairJob
    let shopLevel: Int
    let washLevel: Int
    let apprentices: [Apprentice]
    let catalog: ContentCatalog
    let send: (GameCommand) -> Void
    let startMiniGame: (MiniGameRequest) -> Void
    @State private var concealPartQuality = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            switch job.stage {
            case .awaitingInspection, .awaitingDiagnosis:
                inspectionContent
            case .awaitingPart:
                partContent
            case .readyForRepair:
                repairContent
            case .awaitingPrice:
                priceContent
            }
        }
        .garageCard()
        .padding(.horizontal, 12)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(vehicle?.name ?? "Araç").font(.headline)
                    Text("\(customer?.name ?? "Müşteri") • \(job.serviceKind.title)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(stageTitle).font(.caption2.bold()).foregroundStyle(GarageStyle.orange)
            }
            if job.serviceKind == .faultRepair {
                Text("Şikâyet: “\(job.complaint)”")
                    .font(.subheadline).italic().foregroundStyle(.white.opacity(0.86))
            }
        }
    }

    private var inspectionContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Aracı sen kontrol et. Her işlem oyun zamanını ilerletir.")
                .font(.caption).foregroundStyle(.secondary)

            if !job.findings.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("BULGULAR").font(.caption2.bold()).foregroundStyle(GarageStyle.mint)
                    ForEach(Array(job.findings.enumerated()), id: \.offset) { _, finding in
                        Label(finding, systemImage: "checkmark.circle.fill")
                            .font(.caption).foregroundStyle(.white.opacity(0.82))
                    }
                }
            }

            LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 7) {
                ForEach(InspectionKind.allCases.filter { !job.performedInspections.contains($0) }, id: \.self) { kind in
                    Button {
                        send(.performInspection(jobID: job.id, kind: kind))
                    } label: {
                        VStack(spacing: 3) {
                            Text(kind.title).font(.caption.bold())
                            Text("\(kind.durationMinutes) dk").font(.caption2).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ActionButtonStyle(tint: GarageStyle.raised, foreground: .white))
                }
            }

            if job.performedInspections.count >= 2 {
                Divider().overlay(.white.opacity(0.15))
                Text("Bulgulara uyan teşhisi seç:").font(.caption.bold())
                if job.candidateFaultIDs.isEmpty {
                    Text("Henüz arızaya götüren bir bulgu yok. Başka bir kontrol yap.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    ForEach(job.candidateFaultIDs, id: \.self) { id in
                        if let option = catalog.fault(id: id) {
                            Button(option.name) { send(.diagnose(jobID: job.id, faultID: option.id)) }
                                .buttonStyle(ActionButtonStyle(tint: GarageStyle.orange))
                        }
                    }
                }
            }
        }
    }

    private var partContent: some View {
        VStack(alignment: .leading, spacing: 9) {
            if job.serviceKind == .periodicMaintenance {
                Text("Bakım setini parçacıdan seç. Filtreler, yağ ve sarf malzemeleri birlikte gelir.")
                    .font(.caption).foregroundStyle(.secondary)
            } else if let diagnosedFault {
                Text("Teşhis: \(diagnosedFault.name) • Gereken: \(diagnosedFault.partName)")
                    .font(.subheadline)
            }
            ForEach(PartQuality.allCases, id: \.self) { quality in
                Button {
                    send(.buyPart(jobID: job.id, quality: quality))
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(quality.title).font(.subheadline.bold())
                            Spacer()
                            Text(partCost(quality).liraText).monospacedDigit()
                        }
                        Text(quality.detail)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                }
                .buttonStyle(ActionButtonStyle(tint: quality == .used ? .gray : GarageStyle.orange))
            }
        }
    }

    private var repairContent: some View {
        VStack(alignment: .leading, spacing: 9) {
            if job.serviceKind == .periodicMaintenance {
                Text("Yıllık bakım işlemleri").font(.caption.bold())
                ForEach(job.maintenanceTasks, id: \.self) { task in
                    if job.completedMaintenanceTasks.contains(task) {
                        Label(task.title, systemImage: "checkmark.circle.fill")
                            .font(.subheadline).foregroundStyle(GarageStyle.mint)
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            Button {
                                startMiniGame(.init(
                                    jobID: job.id,
                                    title: task.title,
                                    kind: task.gameKind,
                                    maintenanceTask: task,
                                    projectTask: nil
                                ))
                            } label: {
                                Label(task.title, systemImage: "wrench.adjustable.fill")
                            }
                            .buttonStyle(ActionButtonStyle(tint: GarageStyle.mint))
                            apprenticeMenu(task: task)
                        }
                    }
                }
            } else if let fault = diagnosedFault {
                Button {
                    startMiniGame(.init(
                        jobID: job.id,
                        title: fault.partName,
                        kind: fault.repairGame,
                        maintenanceTask: nil,
                        projectTask: nil
                    ))
                } label: {
                    Label("Tamire Başla", systemImage: "wrench.adjustable.fill")
                }
                .buttonStyle(ActionButtonStyle(tint: GarageStyle.mint))
                apprenticeMenu(task: nil)
            }
        }
    }

    private var priceContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let quality = job.workmanship {
                Label(quality.title, systemImage: "checkmark.seal.fill")
                    .font(.subheadline.bold()).foregroundStyle(GarageStyle.mint)
            }
            Text("\(customer?.appearance ?? "Müşteri") • \(customer?.profileHint ?? "Fiyat tepkisini kestirmek zor")")
                .font(.caption).foregroundStyle(.secondary)
            Text("Usta, müşteriye ne fiyat söyleyeceksin?").font(.caption.bold())
            if let wash = catalog.washLevel(washLevel) {
                if job.isWashed {
                    Label("\(wash.name) tamamlandı, teslime hazır", systemImage: "sparkles")
                        .font(.caption.bold()).foregroundStyle(.blue)
                } else {
                    Button {
                        send(.washVehicle(jobID: job.id))
                    } label: {
                        Label(
                            "\(wash.name) • \(wash.washCost.liraText) • \(wash.durationMinutes) dk",
                            systemImage: "drop.fill"
                        )
                    }
                    .buttonStyle(ActionButtonStyle(tint: .blue))
                }
            } else {
                Label("Teslim yıkaması Gelişim bölümünden açılır", systemImage: "lock.fill")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Toggle("Takılan parçanın kalitesini söyleme", isOn: $concealPartQuality)
                .font(.caption).tint(GarageStyle.danger)
            LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 8) {
                ForEach(PriceStrategy.allCases, id: \.self) { strategy in
                    Button(strategy.title) {
                        send(.setPrice(jobID: job.id, strategy: strategy, hidePartQuality: concealPartQuality))
                    }
                    .buttonStyle(ActionButtonStyle(tint: strategy == .excessive ? GarageStyle.danger : GarageStyle.orange))
                }
            }
        }
    }

    @ViewBuilder
    private func apprenticeMenu(task: MaintenanceTask?) -> some View {
        if !apprentices.isEmpty {
            Menu {
                ForEach(apprentices) { apprentice in
                    Button("\(apprentice.name) • Seviye \(apprentice.level)") {
                        send(.assignApprentice(apprenticeID: apprentice.id, jobID: job.id, task: task))
                    }
                }
            } label: {
                Label("Çırağa İş Ver", systemImage: "person.badge.clock")
                    .font(.caption.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(GarageStyle.raised, in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var stageTitle: String {
        switch job.stage {
        case .awaitingInspection: "KONTROL"
        case .awaitingDiagnosis: "TEŞHİS"
        case .awaitingPart: "PARÇA"
        case .readyForRepair: "TAMİR"
        case .awaitingPrice: "FİYAT"
        }
    }

    private func partCost(_ quality: PartQuality) -> Money {
        if job.serviceKind == .periodicMaintenance {
            let base = Int64(180_000 + job.maintenanceTasks.count * 55_000)
            return Money(minorUnits: base * Int64(quality.costPercent) / 100)
        }
        guard let fault = diagnosedFault else { return .zero }
        return Money(minorUnits: fault.basePartCost.minorUnits * Int64(quality.costPercent) / 100)
    }

    private var vehicle: VehicleDefinition? { catalog.vehicle(id: job.vehicleID) }
    private var customer: CustomerDefinition? { catalog.customer(id: job.customerID) }
    private var diagnosedFault: FaultDefinition? { job.diagnosedFaultID.flatMap(catalog.fault(id:)) }
    private var currentShop: ShopLevelDefinition? { catalog.shopLevel(shopLevel) }
}
