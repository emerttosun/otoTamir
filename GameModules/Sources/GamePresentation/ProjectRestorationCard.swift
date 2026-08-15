import GameDomain
import GameLogic
import SwiftUI

struct ProjectRestorationCard: View {
    let project: ProjectCar
    let catalog: ContentCatalog
    let hasBodyPaintBooth: Bool
    let start: (ProjectRepairTask, String, RepairGameKind) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(vehicle?.name ?? "Proje Araç").font(.headline)
                    Text("İhaleden alınan araç • \(project.purchasePrice.liraText)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(project.completedRepairTasks.count)/\(tasks.count)")
                    .font(.caption.bold().monospacedDigit()).foregroundStyle(GarageStyle.orange)
            }

            SwiftUI.ProgressView(
                value: Double(project.completedRepairTasks.count),
                total: Double(max(1, tasks.count))
            )
            .tint(GarageStyle.orange)

            Text("Aracı satışa hazırlamak için her işi ayrı ayrı tamamla.")
                .font(.caption).foregroundStyle(.secondary)

            ForEach(tasks) { task in
                taskRow(task)
            }
        }
        .garageCard()
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    private func taskRow(_ task: ProjectRepairTask) -> some View {
        let completed = project.completedRepairTasks.contains(task)
        HStack(spacing: 10) {
            Image(systemName: completed ? "checkmark.circle.fill" : icon(task))
                .frame(width: 25)
                .foregroundStyle(completed ? GarageStyle.mint : GarageStyle.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(title(task)).font(.subheadline.weight(.semibold))
                Text(completed ? "Tamamlandı" : "Parça ve işçilik: \(cost(task).liraText)")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            if !completed {
                Button("Yap") { start(task, title(task), gameKind(task)) }
                    .buttonStyle(ActionButtonStyle(tint: GarageStyle.raised, foreground: .white))
                    .accessibilityLabel("\(title(task)) işini başlat")
            }
        }
        .padding(9)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 11))
    }

    private var vehicle: VehicleDefinition? { catalog.vehicle(id: project.vehicleID) }

    private var tasks: [ProjectRepairTask] {
        project.faultIDs.map { .mechanical(faultID: $0) }
            + project.panelDamages.filter {
                VehiclePanel.exteriorCases.contains($0.panel) && $0.condition != .original
            }.map { .panel($0.panel) }
            + project.structuralDamages.filter { $0.condition.requiresRepair }.map { .structural($0.area) }
            + (project.airbagsDeployed ? [.airbag] : [])
    }

    private func title(_ task: ProjectRepairTask) -> String {
        switch task {
        case .mechanical(let faultID): return catalog.fault(id: faultID)?.partName ?? "Mekanik arıza"
        case .panel(let panel):
            let condition = project.panelDamages.first { $0.panel == panel }?.condition.title ?? "Onarım"
            return "\(panel.title) • \(condition)"
        case .structural(let area):
            let condition = project.structuralDamages.first { $0.area == area }?.condition.title ?? "Ölçüm"
            return "\(area.title) • \(condition)"
        case .airbag: return "Hava yastığı ve emniyet sistemi"
        }
    }

    private func icon(_ task: ProjectRepairTask) -> String {
        switch task {
        case .mechanical: "wrench.adjustable.fill"
        case .panel: "car.side.fill"
        case .structural: "ruler.fill"
        case .airbag: "shield.checkered"
        }
    }

    private func gameKind(_ task: ProjectRepairTask) -> RepairGameKind {
        switch task {
        case .mechanical(let faultID): catalog.fault(id: faultID)?.repairGame ?? .timing
        case .panel(let panel):
            switch panel {
            case .leftFrontDoor, .rightFrontDoor, .leftRearDoor, .rightRearDoor,
                 .frontBumper, .rearBumper: .bolts
            default: .alignment
            }
        case .structural: .panelWeld
        case .airbag: .wiring
        }
    }

    private func cost(_ task: ProjectRepairTask) -> Money {
        guard let vehicle else { return .zero }
        return VehicleTradingRules.repairTaskCost(
            task: task,
            project: project,
            vehicle: vehicle,
            catalog: catalog,
            hasBodyPaintBooth: hasBodyPaintBooth
        )
    }
}
