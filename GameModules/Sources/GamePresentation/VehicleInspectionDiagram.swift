import GameDomain
import SwiftUI

struct VehicleInspectionDiagram: View {
    let damages: [PanelDamage]

    private let columns = [
        GridItem(.flexible(), alignment: .leading),
        GridItem(.flexible(), alignment: .leading),
        GridItem(.flexible(), alignment: .leading)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("KAPORTA DURUM ŞEMASI")
                .font(.caption.weight(.black))
                .foregroundStyle(GarageStyle.orange)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 7) {
                legend("Orijinal", .original)
                legend("Boyalı", .painted)
                legend("Değişen", .replaced)
                legend("Hasarlı", .damaged)
                legend("Ağır hasarlı", .heavyDamage)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(Color(red: 0.96, green: 0.94, blue: 0.84).opacity(0.96))

                Canvas { context, size in
                    drawVehicle(in: &context, size: size)
                }
                .padding(12)

                VStack {
                    Label("ÖN", systemImage: "arrow.up")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(Color.black.opacity(0.55))
                    Spacer()
                }
                .padding(.top, 8)
            }
            .frame(maxWidth: 330)
            .frame(height: 330)
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 7) {
                Text("TAŞIYICI YAPI")
                    .font(.system(size: 9, weight: .black)).foregroundStyle(.secondary)
                HStack(spacing: 7) {
                    structurePill(.chassis)
                    structurePill(.leftPillar)
                    structurePill(.rightPillar)
                }
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 15))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private func drawVehicle(in context: inout GraphicsContext, size: CGSize) {
        drawWheels(in: &context, size: size)

        let visiblePanels: [VehiclePanel] = [
            .frontBumper, .hood,
            .leftFrontFender, .rightFrontFender,
            .leftFrontDoor, .rightFrontDoor,
            .leftRearDoor, .rightRearDoor,
            .leftRearFender, .rightRearFender,
            .roof, .trunk, .rearBumper
        ]

        for panel in visiblePanels {
            let path = panelPath(panel, size: size)
            context.fill(path, with: .color(color(condition(for: panel))))
            context.stroke(path, with: .color(.white.opacity(0.9)), lineWidth: 1.5)
        }

        drawGlass(in: &context, size: size)
    }

    private func drawWheels(in context: inout GraphicsContext, size: CGSize) {
        let wheelRects = [
            normalizedRect(x: 0.075, y: 0.20, width: 0.105, height: 0.13, size: size),
            normalizedRect(x: 0.82, y: 0.20, width: 0.105, height: 0.13, size: size),
            normalizedRect(x: 0.075, y: 0.69, width: 0.105, height: 0.13, size: size),
            normalizedRect(x: 0.82, y: 0.69, width: 0.105, height: 0.13, size: size)
        ]
        for rect in wheelRects {
            context.fill(Path(ellipseIn: rect), with: .color(Color(red: 0.72, green: 0.73, blue: 0.74)))
            context.stroke(Path(ellipseIn: rect), with: .color(.white.opacity(0.9)), lineWidth: 2)
        }
    }

    private func drawGlass(in context: inout GraphicsContext, size: CGSize) {
        let frontGlass = polygon([
            (0.36, 0.325), (0.64, 0.325), (0.62, 0.385), (0.38, 0.385)
        ], size: size)
        let rearGlass = polygon([
            (0.38, 0.635), (0.62, 0.635), (0.64, 0.695), (0.36, 0.695)
        ], size: size)
        context.fill(frontGlass, with: .color(.white.opacity(0.94)))
        context.fill(rearGlass, with: .color(.white.opacity(0.94)))
        context.stroke(frontGlass, with: .color(Color.gray.opacity(0.35)), lineWidth: 1)
        context.stroke(rearGlass, with: .color(Color.gray.opacity(0.35)), lineWidth: 1)
    }

    private func panelPath(_ panel: VehiclePanel, size: CGSize) -> Path {
        switch panel {
        case .frontBumper:
            return Path(roundedRect: normalizedRect(x: 0.35, y: 0.045, width: 0.30, height: 0.055, size: size), cornerRadius: 6)
        case .hood:
            return polygon([(0.36, 0.13), (0.64, 0.13), (0.66, 0.31), (0.34, 0.31)], size: size)
        case .leftFrontFender:
            return polygon([(0.18, 0.15), (0.30, 0.13), (0.29, 0.32), (0.17, 0.30), (0.16, 0.20)], size: size)
        case .rightFrontFender:
            return polygon([(0.70, 0.13), (0.82, 0.15), (0.84, 0.20), (0.83, 0.30), (0.71, 0.32)], size: size)
        case .leftFrontDoor:
            return polygon([(0.17, 0.335), (0.29, 0.345), (0.29, 0.515), (0.17, 0.505)], size: size)
        case .rightFrontDoor:
            return polygon([(0.71, 0.345), (0.83, 0.335), (0.83, 0.505), (0.71, 0.515)], size: size)
        case .roof:
            return Path(roundedRect: normalizedRect(x: 0.37, y: 0.40, width: 0.26, height: 0.22, size: size), cornerRadius: 5)
        case .leftRearDoor:
            return polygon([(0.17, 0.53), (0.29, 0.53), (0.30, 0.705), (0.17, 0.72)], size: size)
        case .rightRearDoor:
            return polygon([(0.71, 0.53), (0.83, 0.53), (0.83, 0.72), (0.70, 0.705)], size: size)
        case .leftRearFender:
            return polygon([(0.17, 0.74), (0.30, 0.72), (0.29, 0.88), (0.20, 0.90), (0.17, 0.85)], size: size)
        case .rightRearFender:
            return polygon([(0.70, 0.72), (0.83, 0.74), (0.83, 0.85), (0.80, 0.90), (0.71, 0.88)], size: size)
        case .trunk:
            return polygon([(0.35, 0.71), (0.65, 0.71), (0.66, 0.87), (0.34, 0.87)], size: size)
        case .rearBumper:
            return Path(roundedRect: normalizedRect(x: 0.35, y: 0.90, width: 0.30, height: 0.055, size: size), cornerRadius: 6)
        case .chassis:
            return polygon([
                (0.34, 0.115), (0.66, 0.115), (0.68, 0.31), (0.65, 0.39),
                (0.66, 0.70), (0.68, 0.88), (0.32, 0.88), (0.34, 0.70),
                (0.35, 0.39), (0.32, 0.31)
            ], size: size)
        case .leftPillar:
            return Path(roundedRect: normalizedRect(x: 0.305, y: 0.335, width: 0.035, height: 0.385, size: size), cornerRadius: 2)
        case .rightPillar:
            return Path(roundedRect: normalizedRect(x: 0.66, y: 0.335, width: 0.035, height: 0.385, size: size), cornerRadius: 2)
        }
    }

    private func polygon(_ points: [(CGFloat, CGFloat)], size: CGSize) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: CGPoint(x: first.0 * size.width, y: first.1 * size.height))
        for point in points.dropFirst() {
            path.addLine(to: CGPoint(x: point.0 * size.width, y: point.1 * size.height))
        }
        path.closeSubpath()
        return path
    }

    private func normalizedRect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, size: CGSize) -> CGRect {
        CGRect(x: x * size.width, y: y * size.height, width: width * size.width, height: height * size.height)
    }

    private func condition(for panel: VehiclePanel) -> PanelCondition {
        damages.first(where: { $0.panel == panel })?.condition ?? .original
    }

    private func legend(_ title: String, _ condition: PanelCondition) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color(condition))
                .frame(width: 13, height: 13)
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .lineLimit(1)
        }
    }

    private func structurePill(_ panel: VehiclePanel) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color(condition(for: panel))).frame(width: 8, height: 8)
            Text(panel == .chassis ? "Şasi" : (panel == .leftPillar ? "Sol direk" : "Sağ direk"))
                .font(.system(size: 9, weight: .semibold)).lineLimit(1)
        }
        .padding(.horizontal, 7).padding(.vertical, 6)
        .background(Color.white.opacity(0.05), in: Capsule())
    }

    private func color(_ condition: PanelCondition) -> Color {
        switch condition {
        case .original: Color(red: 0.61, green: 0.61, blue: 0.61)
        case .painted: Color(red: 0.25, green: 0.52, blue: 0.79)
        case .replaced: Color(red: 1.0, green: 0.33, blue: 0.23)
        case .damaged: Color(red: 1.0, green: 0.58, blue: 0.28)
        case .heavyDamage: Color(red: 0.68, green: 0.12, blue: 0.13)
        }
    }

    private var accessibilitySummary: String {
        let changed = damages.filter { $0.condition != .original }
            .map { "\($0.panel.title): \($0.condition.title)" }
            .joined(separator: ", ")
        return changed.isEmpty ? "Kaporta durum şeması, bütün parçalar orijinal" : "Kaporta durum şeması, \(changed)"
    }
}
