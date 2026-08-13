import GameDomain
import SwiftUI

struct WorkshopView: View {
    @ObservedObject var store: GameStore
    @State private var selectedRepairJob: RepairJob?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                GarageSceneView(state: store.state, catalog: store.catalog)
                    .frame(height: 230)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(.horizontal, 12)

                if !store.state.activeJobs.isEmpty {
                    sectionTitle("Liftteki İşler", icon: "car.side.fill")
                    ForEach(store.state.activeJobs) { job in
                        JobCard(job: job, catalog: store.catalog) { command in
                            store.send(command)
                        } startRepair: {
                            selectedRepairJob = job
                        }
                    }
                }

                sectionTitle("Bugünün Müşterileri", icon: "person.3.fill")
                if store.state.offers.isEmpty {
                    emptyCard("Bugünün teklifleri bitti. Bekleyen işi tamamlayabilir veya günü kapatabilirsin.")
                } else {
                    ForEach(store.state.offers) { offer in
                        OfferCard(offer: offer, catalog: store.catalog) {
                            store.send(.acceptOffer(offer.id))
                        }
                    }
                }

                Button {
                    store.send(.endDay)
                } label: {
                    Label("Kepengi Kapat ve Günü Bitir", systemImage: "moon.stars.fill")
                }
                .buttonStyle(ActionButtonStyle(tint: .white.opacity(0.82)))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .padding(.bottom, 22)
        }
        .sheet(item: $selectedRepairJob) { job in
            if let diagnosedID = job.diagnosedFaultID,
               let fault = store.catalog.fault(id: diagnosedID) {
                RepairMiniGameHost(kind: fault.repairGame, partName: fault.partName) { score in
                    selectedRepairJob = nil
                    store.send(.completeRepair(jobID: job.id, performance: score))
                }
            }
        }
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

private struct OfferCard: View {
    let offer: CustomerOffer
    let catalog: ContentCatalog
    let accept: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(customer?.name ?? "Müşteri").font(.headline)
                    Text(customer?.archetype ?? "").font(.caption).foregroundStyle(GarageStyle.orange)
                }
                Spacer()
                Text(vehicle?.name ?? "Araç")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(GarageStyle.raised, in: Capsule())
            }
            Text("“\(offer.complaint)”")
                .font(.subheadline)
                .italic()
                .foregroundStyle(.white.opacity(0.86))
            Text(customer?.greeting ?? "")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Aracı Kabul Et", action: accept)
                .buttonStyle(ActionButtonStyle())
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
    let catalog: ContentCatalog
    let send: (GameCommand) -> Void
    let startRepair: () -> Void
    @State private var concealPartQuality = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text(vehicle?.name ?? "Araç").font(.headline)
                    Text(customer?.name ?? "Müşteri").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(stageTitle)
                    .font(.caption2.bold())
                    .foregroundStyle(GarageStyle.orange)
            }

            switch job.stage {
            case .awaitingDiagnosis:
                diagnosisContent
            case .awaitingQuote:
                quoteContent
            case .awaitingPart:
                partContent
            case .readyForRepair:
                Button {
                    startRepair()
                } label: {
                    Label("Tamire Başla", systemImage: "wrench.adjustable.fill")
                }
                .buttonStyle(ActionButtonStyle(tint: GarageStyle.mint))
            case .completed:
                EmptyView()
            }
        }
        .garageCard()
        .padding(.horizontal, 12)
    }

    private var diagnosisContent: some View {
        VStack(alignment: .leading, spacing: 9) {
            if let actualFault {
                ForEach(actualFault.clues, id: \.self) { clue in
                    Label(clue, systemImage: "waveform.path.ecg")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.78))
                }
            }
            Text("Teşhisin:").font(.caption.bold())
            ForEach(job.suspectedFaultIDs, id: \.self) { id in
                if let option = catalog.fault(id: id) {
                    Button(option.name) { send(.diagnose(jobID: job.id, faultID: option.id)) }
                        .buttonStyle(ActionButtonStyle(tint: GarageStyle.raised))
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private var quoteContent: some View {
        VStack(alignment: .leading, spacing: 9) {
            if let diagnosedFault {
                Text("İş: \(diagnosedFault.name) • \(diagnosedFault.partName)")
                    .font(.subheadline)
            }
            Toggle("Parça kalitesini müşteriden sakla", isOn: $concealPartQuality)
                .font(.caption)
                .tint(GarageStyle.danger)
            HStack(spacing: 8) {
                ForEach(PriceStrategy.allCases, id: \.self) { strategy in
                    Button(strategy.title) {
                        send(.setQuote(jobID: job.id, strategy: strategy, hidePartQuality: concealPartQuality))
                    }
                    .buttonStyle(ActionButtonStyle(tint: strategy == .excessive ? GarageStyle.danger : GarageStyle.orange))
                }
            }
        }
    }

    private var partContent: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Parçacıdan hangisini isteyelim?").font(.caption.bold())
            ForEach(PartQuality.allCases, id: \.self) { quality in
                Button {
                    send(.buyPart(jobID: job.id, quality: quality))
                } label: {
                    HStack {
                        Text(quality.title)
                        Spacer()
                        Text(partCost(quality).liraText).monospacedDigit()
                    }
                }
                .buttonStyle(ActionButtonStyle(tint: quality == .used ? .gray : GarageStyle.orange))
            }
        }
    }

    private var stageTitle: String {
        switch job.stage {
        case .awaitingDiagnosis: "TEŞHİS"
        case .awaitingQuote: "FİYAT"
        case .awaitingPart: "PARÇA"
        case .readyForRepair: "TAMİR"
        case .completed: "TAMAM"
        }
    }

    private func partCost(_ quality: PartQuality) -> Money {
        guard let fault = diagnosedFault else { return .zero }
        return Money(minorUnits: fault.basePartCost.minorUnits * Int64(quality.costPercent) / 100)
    }

    private var vehicle: VehicleDefinition? { catalog.vehicle(id: job.vehicleID) }
    private var customer: CustomerDefinition? { catalog.customer(id: job.customerID) }
    private var actualFault: FaultDefinition? { catalog.fault(id: job.actualFaultID) }
    private var diagnosedFault: FaultDefinition? { job.diagnosedFaultID.flatMap(catalog.fault(id:)) }
}
