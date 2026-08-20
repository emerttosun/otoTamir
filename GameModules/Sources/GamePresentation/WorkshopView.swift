import GameDomain
import Foundation
import GameLogic
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
                            catalog: store.catalog,
                            partPurchasePrice: store.state.inventory.first { $0.jobID == selectedJob.id }?.purchasePrice
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
                title: store.catalog.part(for: fault)?.name ?? fault.name,
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
    let partPurchasePrice: Money?
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
            case .awaitingPrice:
                quoteContent
            case .negotiating:
                negotiationContent
            case .readyForRepair:
                repairContent
            case .awaitingDelivery:
                deliveryContent
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
                Text("Değişecek parçalar")
                    .font(.caption.bold())
                ForEach(maintenanceParts) { part in
                    HStack(alignment: .firstTextBaseline) {
                        Text(part.name)
                        Spacer()
                        Text(part.basePrice.liraText)
                            .monospacedDigit()
                    }
                    .font(.caption)
                }
                let inspections = job.maintenanceTasks.filter {
                    catalog.maintenanceService(for: $0)?.partIDs.isEmpty == true
                }
                if !inspections.isEmpty {
                    Text("\(inspections.map(\.title).joined(separator: ", ")) yalnız kontrol işlemidir; parça bedeli eklenmez.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Text("Parça kalitesini seç. Aşağıdaki tutar değişecek parçaların toplam alış fiyatıdır.")
                    .font(.caption).foregroundStyle(.secondary)
            } else if let diagnosedFault {
                Text("Teşhis: \(diagnosedFault.name) • Gereken: \(diagnosedPart?.name ?? "parça kaydı eksik")")
                    .font(.subheadline)
            }
            ForEach(PartQuality.allCases, id: \.self) { quality in
                Button {
                    send(.buyPart(jobID: job.id, quality: quality))
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(quality.title(for: qualityProfile))
                                .font(.subheadline.bold())
                                .lineLimit(1)
                            Spacer()
                            Text(partCost(quality).liraText)
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        Text(quality.detail(for: qualityProfile))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.horizontal, 14)
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
                        title: diagnosedPart?.name ?? fault.name,
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

    private var quoteContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(customer?.appearance ?? "Müşteri") • \(customer?.profileHint ?? "Fiyat tepkisini kestirmek zor")")
                .font(.caption).foregroundStyle(.secondary)
            VStack(spacing: 7) {
                quoteRow("Parça ücreti", amount: quoteBreakdown.partCost)
                quoteRow("İşçilik", amount: quoteBreakdown.laborCost)
                Divider().overlay(.white.opacity(0.15))
                quoteRow("Normal toplam", amount: quoteBreakdown.normalTotal, emphasized: true)
            }
            .padding(12)
            .background(GarageStyle.raised.opacity(0.72), in: RoundedRectangle(cornerRadius: 12))
            Text("Tamire başlamadan önce müşteriye fiyat söyle.").font(.caption.bold())
            Toggle("Takılan parçanın kalitesini söyleme", isOn: $concealPartQuality)
                .font(.caption).tint(GarageStyle.danger)
            LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 8) {
                ForEach(PriceStrategy.allCases, id: \.self) { strategy in
                    Button {
                        send(.setPrice(jobID: job.id, strategy: strategy, hidePartQuality: concealPartQuality))
                    } label: {
                        VStack(spacing: 2) {
                            Text(strategy.title)
                            Text(quoteBreakdown.amount(for: strategy).liraText)
                                .font(.caption2.bold())
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ActionButtonStyle(tint: strategy == .excessive ? GarageStyle.danger : GarageStyle.orange))
                    .accessibilityLabel("\(strategy.title) istenen fiyat, \(quoteBreakdown.amount(for: strategy).liraText)")
                }
            }
            Text("Bu müşteriye söyleyeceğin ilk fiyattır. Fiyat bilgisi yüksek müşteri karşı teklif verebilir.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var negotiationContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Müşteri karşı teklif verdi", systemImage: "bubble.left.and.bubble.right.fill")
                .font(.subheadline.bold())
                .foregroundStyle(GarageStyle.orange)
            quoteRow("Senin fiyatın", amount: job.initialQuote ?? .zero)
            quoteRow("Müşterinin teklifi", amount: job.customerCounterOffer ?? .zero, emphasized: true)

            Button(CustomerNegotiationResponse.acceptCounter.title) {
                send(.respondToCustomerOffer(jobID: job.id, response: .acceptCounter))
            }
            .buttonStyle(ActionButtonStyle(tint: GarageStyle.mint))

            Button {
                send(.respondToCustomerOffer(jobID: job.id, response: .meetHalfway))
            } label: {
                Text("Ortada Buluş • \(halfwayPrice.liraText)")
            }
            .buttonStyle(ActionButtonStyle(tint: GarageStyle.orange))

            Button(CustomerNegotiationResponse.insist.title) {
                send(.respondToCustomerOffer(jobID: job.id, response: .insist))
            }
            .buttonStyle(ActionButtonStyle(tint: GarageStyle.danger))
        }
    }

    private var deliveryContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let quality = job.workmanship {
                Label(quality.title, systemImage: "checkmark.seal.fill")
                    .font(.subheadline.bold()).foregroundStyle(GarageStyle.mint)
            }
            VStack(spacing: 7) {
                quoteRow("Kullanılan parça", amount: quoteBreakdown.partCost)
                HStack {
                    Text(partDescription)
                    Spacer()
                    Text(job.hidePartQuality ? "Kalite gizli" : (job.partQuality?.title(for: qualityProfile) ?? "—"))
                }
                .font(.caption)
                .foregroundStyle(job.hidePartQuality ? GarageStyle.danger : .secondary)
                quoteRow("İşçilik", amount: quoteBreakdown.laborCost)
                Divider().overlay(.white.opacity(0.15))
                quoteRow("Anlaşılan toplam", amount: job.quote ?? .zero, emphasized: true)
            }
            .padding(12)
            .background(GarageStyle.raised.opacity(0.72), in: RoundedRectangle(cornerRadius: 12))

            washControls

            Button {
                send(.deliverVehicle(jobID: job.id))
            } label: {
                Label("Teslim Et • \((job.quote ?? .zero).liraText)", systemImage: "key.fill")
            }
            .buttonStyle(ActionButtonStyle(tint: GarageStyle.mint))
            .accessibilityLabel("Aracı teslim et ve \((job.quote ?? .zero).liraText) tahsil et")
        }
    }

    @ViewBuilder
    private var washControls: some View {
        if let wash = catalog.washLevel(washLevel) {
            if job.isWashed {
                Label("\(wash.name) tamamlandı, teslime hazır", systemImage: "sparkles")
                    .font(.caption.bold()).foregroundStyle(.blue)
            } else {
                Button {
                    send(.washVehicle(jobID: job.id))
                } label: {
                    Label(
                        "Usta Yıkasın • \(wash.washCost.liraText) • \(wash.durationMinutes) dk",
                        systemImage: "drop.fill"
                    )
                }
                .buttonStyle(ActionButtonStyle(tint: .blue))

                if !apprentices.isEmpty {
                    Menu {
                        ForEach(apprentices) { apprentice in
                            Button("\(apprentice.name) • +8 XP") {
                                send(.assignApprenticeToWash(apprenticeID: apprentice.id, jobID: job.id))
                            }
                        }
                    } label: {
                        Label("Çırağa Yıkat", systemImage: "person.fill.checkmark")
                            .font(.caption.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(.blue.opacity(0.18), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        } else {
            Label("Teslim yıkaması Gelişim bölümünden açılır", systemImage: "lock.fill")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func quoteRow(
        _ title: String,
        amount: Money,
        emphasized: Bool = false
    ) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(amount.liraText)
                .monospacedDigit()
        }
        .font(emphasized ? .subheadline.bold() : .caption)
        .foregroundStyle(emphasized ? .primary : .secondary)
    }

    @ViewBuilder
    private func apprenticeMenu(task: MaintenanceTask?) -> some View {
        if !apprentices.isEmpty {
            Menu {
                ForEach(apprentices) { apprentice in
                    let assessment = apprenticeAssessment(apprentice, task: task)
                    Button("\(apprentice.name) • \(assessment.area.title) Sv.\(assessment.level) / \(assessment.required)") {
                        send(.assignApprentice(apprenticeID: apprentice.id, jobID: job.id, task: task))
                    }
                    .disabled(!assessment.canPerform)
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

    private func apprenticeAssessment(
        _ apprentice: Apprentice,
        task: MaintenanceTask?
    ) -> (area: SkillArea, level: Int, required: Int, canPerform: Bool) {
        if let task {
            return (
                task.skillArea,
                apprentice.skillLevel(for: task.skillArea),
                ApprenticeRules.requiredLevel(for: task),
                ApprenticeRules.canPerform(task, apprentice: apprentice)
            )
        }
        if let fault = diagnosedFault {
            return (
                fault.area,
                apprentice.skillLevel(for: fault.area),
                ApprenticeRules.requiredLevel(for: fault),
                ApprenticeRules.canPerform(fault, apprentice: apprentice)
            )
        }
        return (.engine, apprentice.skillLevel(for: .engine), 1, false)
    }

    private var stageTitle: String {
        switch job.stage {
        case .awaitingInspection: "KONTROL"
        case .awaitingDiagnosis: "TEŞHİS"
        case .awaitingPart: "PARÇA"
        case .awaitingPrice: "FİYAT"
        case .negotiating: "PAZARLIK"
        case .readyForRepair: "TAMİR"
        case .awaitingDelivery: "TESLİM"
        }
    }

    private func partCost(_ quality: PartQuality) -> Money {
        let baseCost = job.serviceKind == .periodicMaintenance
            ? PartPricingRules.maintenanceBasePartCost(for: job.maintenanceTasks, catalog: catalog)
            : diagnosedPart?.basePrice ?? .zero
        return PartPricingRules.purchasePrice(
            baseCost: baseCost,
            quality: quality,
            profile: qualityProfile
        )
    }

    private var qualityProfile: PartQualityProfile {
        job.serviceKind == .periodicMaintenance ? .maintenanceSupply : .replacementPart
    }

    private var quoteBreakdown: CustomerQuoteBreakdown {
        CustomerPricingRules.quote(
            partCost: partPurchasePrice ?? .zero,
            for: job,
            catalog: catalog
        )
    }

    private var halfwayPrice: Money {
        CustomerNegotiationRules.halfway(
            askingPrice: job.initialQuote ?? .zero,
            counterOffer: job.customerCounterOffer ?? .zero
        )
    }

    private var partDescription: String {
        if job.serviceKind == .periodicMaintenance {
            return maintenanceParts.map(\.name).joined(separator: ", ")
        }
        return diagnosedPart?.name ?? "Parça"
    }

    private var maintenanceParts: [PartDefinition] {
        PartPricingRules.maintenanceParts(for: job.maintenanceTasks, catalog: catalog)
    }

    private var vehicle: VehicleDefinition? { catalog.vehicle(id: job.vehicleID) }
    private var customer: CustomerDefinition? { catalog.customer(id: job.customerID) }
    private var diagnosedFault: FaultDefinition? { job.diagnosedFaultID.flatMap(catalog.fault(id:)) }
    private var diagnosedPart: PartDefinition? { diagnosedFault.flatMap(catalog.part(for:)) }
}
