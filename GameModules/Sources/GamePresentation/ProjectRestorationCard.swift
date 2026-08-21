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
                    Text("Hasarlı'dan alınan araç • \(project.purchasePrice.liraText)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(project.completedRepairTasks.count)/\(requiredTasks.count)")
                    .font(.caption.bold().monospacedDigit()).foregroundStyle(GarageStyle.orange)
            }

            SwiftUI.ProgressView(
                value: Double(project.completedRepairTasks.count),
                total: Double(max(1, requiredTasks.count))
            )
            .tint(GarageStyle.orange)

            Text("Zorunlu işleri tamamlayınca araç satışa hazır olur.")
                .font(.caption).foregroundStyle(.secondary)

            ForEach(requiredTasks) { task in
                taskRow(task, optional: false)
            }

            if !optionalTasks.isEmpty {
                Divider().overlay(.white.opacity(0.12))
                VStack(alignment: .leading, spacing: 3) {
                    Text("İSTEĞE BAĞLI YIPRANMIŞ PARÇALAR")
                        .font(.caption2.bold()).foregroundStyle(GarageStyle.mint)
                    Text("Bu parçalar kullanılabilir. Değiştirirsen maliyet artar; kondisyon ve adil satış değeri yükselir.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                ForEach(optionalTasks) { task in
                    taskRow(task, optional: true)
                }
            }
        }
        .garageCard()
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    private func taskRow(_ task: ProjectRepairTask, optional: Bool) -> some View {
        let completed = optional
            ? project.completedOptionalRepairTasks.contains(task)
            : project.completedRepairTasks.contains(task)
        HStack(spacing: 10) {
            Image(systemName: completed ? "checkmark.circle.fill" : icon(task))
                .frame(width: 25)
                .foregroundStyle(completed ? GarageStyle.mint : GarageStyle.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(title(task)).font(.subheadline.weight(.semibold))
                Text(completed
                     ? (optional ? "Yenilendi • kondisyon katkısı işlendi" : "Tamamlandı")
                     : (optional ? "Orta durumda • değişim: \(cost(task).liraText)" : "Parça ve işçilik: \(cost(task).liraText)"))
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            if !completed {
                Button(optional ? "Değiştir" : "Yap") { start(task, title(task), gameKind(task)) }
                    .buttonStyle(ActionButtonStyle(tint: GarageStyle.raised, foreground: .white))
                    .accessibilityLabel("\(title(task)) işini başlat")
            }
        }
        .padding(9)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 11))
    }

    private var vehicle: VehicleDefinition? { catalog.vehicle(id: project.vehicleID) }

    private var requiredTasks: [ProjectRepairTask] {
        project.faultIDs.map { .mechanical(faultID: $0) }
            + project.panelDamages.filter {
                VehiclePanel.exteriorCases.contains($0.panel) && $0.condition != .original
            }.map { .panel($0.panel) }
            + project.structuralDamages.filter { $0.condition.requiresRepair }.map { .structural($0.area) }
            + (project.airbagsDeployed ? [.airbag] : [])
    }

    private var optionalTasks: [ProjectRepairTask] {
        project.optionalFaultIDs.map { .mechanical(faultID: $0) }
    }

    private func title(_ task: ProjectRepairTask) -> String {
        switch task {
        case .mechanical(let faultID):
            return catalog.fault(id: faultID).flatMap(catalog.part(for:))?.name ?? "Mekanik arıza"
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
            case .leftFrontDoor, .rightFrontDoor, .leftRearDoor, .rightRearDoor: .doorGap
            case .frontBumper, .rearBumper: .bumperClips
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
