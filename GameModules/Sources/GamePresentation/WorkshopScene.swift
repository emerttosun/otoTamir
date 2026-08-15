import GameDomain
import SpriteKit
import SwiftUI

enum WorkshopVehicleSelection: Hashable {
    case job(UUID)
    case project(UUID)

    var id: UUID {
        switch self {
        case .job(let id), .project(let id): id
        }
    }
}

@MainActor
public final class WorkshopScene: SKScene {
    private let catalog: ContentCatalog
    private var currentState: GameState
    private var selectedVehicle: WorkshopVehicleSelection?
    private var selectionHandler: (WorkshopVehicleSelection) -> Void

    init(
        size: CGSize,
        state: GameState,
        catalog: ContentCatalog,
        selection: WorkshopVehicleSelection?,
        onSelect: @escaping (WorkshopVehicleSelection) -> Void
    ) {
        self.catalog = catalog
        currentState = state
        selectedVehicle = selection
        selectionHandler = onSelect
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = SKColor(red: 0.06, green: 0.065, blue: 0.07, alpha: 1)
        buildEnvironment()
        update(state: state, selection: selection)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { nil }

    override public func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        resizeBackground()
        guard childNode(withName: "workshop-background") != nil else { return }
        renderVehicles()
    }

    func update(state: GameState, selection: WorkshopVehicleSelection?) {
        currentState = state
        selectedVehicle = selection
        renderVehicles()
    }

    private func renderVehicles() {
        childNode(withName: "vehicle-layer")?.removeFromParent()
        childNode(withName: "empty-state")?.removeFromParent()

        let vehicles = workshopVehicles(state: currentState)
        guard !vehicles.isEmpty else {
            addEmptyState()
            return
        }

        let positions = horizontalPositions(count: vehicles.count)
        let vehicleWidth: CGFloat
        switch vehicles.count {
        case 1: vehicleWidth = 225
        case 2: vehicleWidth = 155
        case 3: vehicleWidth = 108
        case 4: vehicleWidth = 86
        default: vehicleWidth = 70
        }
        let layer = SKNode()
        layer.name = "vehicle-layer"
        addChild(layer)
        for (index, vehicle) in vehicles.enumerated() {
            addVehicle(vehicle, x: size.width * positions[index], width: vehicleWidth, to: layer)
        }
    }

    #if os(iOS)
    override public func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else { return }
        var node: SKNode? = atPoint(point)
        while let current = node {
            if let name = current.name, name.hasPrefix("vehicle-select:"),
               let selection = decodeSelection(name) {
                selectionHandler(selection)
                return
            }
            node = current.parent
        }
    }
    #endif

    private func buildEnvironment() {
        let background = SKSpriteNode(imageNamed: "workshop-background-v1")
        background.name = "workshop-background"
        background.zPosition = -20
        addChild(background)
        resizeBackground()

        let shade = SKShapeNode(rect: CGRect(origin: .zero, size: size))
        shade.name = "workshop-shade"
        shade.fillColor = SKColor.black.withAlphaComponent(0.08)
        shade.strokeColor = .clear
        shade.zPosition = -10
        addChild(shade)
    }

    private func resizeBackground() {
        guard let background = childNode(withName: "workshop-background") as? SKSpriteNode else { return }
        let textureSize = background.texture?.size() ?? CGSize(width: 16, height: 9)
        let scale = max(size.width / textureSize.width, size.height / textureSize.height)
        background.size = CGSize(width: textureSize.width * scale, height: textureSize.height * scale)
        background.position = CGPoint(x: size.width / 2, y: size.height / 2)
        if let shade = childNode(withName: "workshop-shade") as? SKShapeNode {
            shade.path = CGPath(rect: CGRect(origin: .zero, size: size), transform: nil)
        }
    }

    private func addVehicle(_ vehicle: SceneVehicle, x: CGFloat, width: CGFloat, to layer: SKNode) {
        let root = SKNode()
        root.name = "vehicle-select:\(vehicle.selectionKey)"
        root.position = CGPoint(x: x, y: size.height * 0.24)
        root.zPosition = 5

        if selectedVehicle == vehicle.selection {
            let selection = SKShapeNode(rectOf: CGSize(width: width + 24, height: width * 0.58), cornerRadius: 16)
            selection.fillColor = SKColor(red: 1, green: 0.48, blue: 0.12, alpha: 0.16)
            selection.strokeColor = SKColor(red: 1, green: 0.48, blue: 0.12, alpha: 1)
            selection.lineWidth = 4
            selection.position = CGPoint(x: 0, y: 7)
            root.addChild(selection)
        }

        let car = SKSpriteNode(imageNamed: "workshop-car-sprite-v1")
        let aspect = max(0.35, car.texture.map { $0.size().height / $0.size().width } ?? 0.45)
        car.size = CGSize(width: width, height: width * aspect)
        car.color = vehicle.color
        car.colorBlendFactor = 0.32
        car.position = CGPoint(x: 0, y: 14)
        root.addChild(car)

        if vehicle.isDamaged {
            let warning = SKLabelNode(text: "⚠︎")
            warning.fontName = "AvenirNext-Heavy"
            warning.fontSize = width * 0.18
            warning.fontColor = .systemOrange
            warning.position = CGPoint(x: width * 0.34, y: width * 0.15)
            warning.zPosition = 3
            root.addChild(warning)
        }

        let labelBackground = SKShapeNode(rectOf: CGSize(width: width + 8, height: 36), cornerRadius: 9)
        labelBackground.fillColor = SKColor.black.withAlphaComponent(0.76)
        labelBackground.strokeColor = selectedVehicle == vehicle.selection
            ? SKColor(red: 1, green: 0.48, blue: 0.12, alpha: 1)
            : SKColor.white.withAlphaComponent(0.22)
        labelBackground.position = CGPoint(x: 0, y: -width * aspect * 0.43)
        root.addChild(labelBackground)

        let name = SKLabelNode(text: vehicle.name)
        name.fontName = "AvenirNext-DemiBold"
        name.fontSize = vehiclesFontSize(width: width)
        name.fontColor = .white
        name.verticalAlignmentMode = .center
        name.position = CGPoint(x: 0, y: 6)
        labelBackground.addChild(name)

        let status = SKLabelNode(text: vehicle.status)
        status.fontName = "AvenirNext-Bold"
        status.fontSize = max(8, vehiclesFontSize(width: width) - 3)
        status.fontColor = vehicle.isProject ? .systemOrange : SKColor(red: 0.35, green: 0.82, blue: 0.68, alpha: 1)
        status.verticalAlignmentMode = .center
        status.position = CGPoint(x: 0, y: -8)
        labelBackground.addChild(status)

        layer.addChild(root)
    }

    private func addEmptyState() {
        let background = SKShapeNode(rectOf: CGSize(width: min(250, size.width * 0.7), height: 54), cornerRadius: 13)
        background.name = "empty-state"
        background.fillColor = SKColor.black.withAlphaComponent(0.68)
        background.strokeColor = SKColor.white.withAlphaComponent(0.22)
        background.position = CGPoint(x: size.width / 2, y: size.height * 0.24)

        let label = SKLabelNode(text: "Liftler boş • müşteri kabul et")
        label.fontName = "AvenirNext-DemiBold"
        label.fontSize = 14
        label.verticalAlignmentMode = .center
        background.addChild(label)
        addChild(background)
    }

    private func workshopVehicles(state: GameState) -> [SceneVehicle] {
        let jobs = state.activeJobs.compactMap { job -> SceneVehicle? in
            guard let vehicle = catalog.vehicle(id: job.vehicleID) else { return nil }
            return SceneVehicle(
                selection: .job(job.id),
                name: vehicle.name,
                status: job.stage.sceneTitle,
                color: SKColor(hex: vehicle.accentHex),
                isProject: false,
                isDamaged: false
            )
        }
        let projects = state.projectCars.compactMap { project -> SceneVehicle? in
            guard let vehicle = catalog.vehicle(id: project.vehicleID) else { return nil }
            return SceneVehicle(
                selection: .project(project.id),
                name: vehicle.name,
                status: project.stage.sceneTitle,
                color: SKColor(hex: vehicle.accentHex),
                isProject: true,
                isDamaged: project.stage == .awaitingRepair
            )
        }
        return Array((jobs + projects).prefix(5))
    }

    private func horizontalPositions(count: Int) -> [CGFloat] {
        switch count {
        case 1: [0.5]
        case 2: [0.25, 0.75]
        case 3: [0.18, 0.5, 0.82]
        case 4: [0.12, 0.37, 0.63, 0.88]
        default: [0.09, 0.295, 0.5, 0.705, 0.91]
        }
    }

    private func vehiclesFontSize(width: CGFloat) -> CGFloat {
        width >= 200 ? 13 : (width >= 160 ? 11 : 9)
    }

    private func decodeSelection(_ name: String) -> WorkshopVehicleSelection? {
        let parts = name.split(separator: ":")
        guard parts.count == 3, let id = UUID(uuidString: String(parts[2])) else { return nil }
        switch parts[1] {
        case "job": return .job(id)
        case "project": return .project(id)
        default: return nil
        }
    }
}

private struct SceneVehicle {
    let selection: WorkshopVehicleSelection
    let name: String
    let status: String
    let color: SKColor
    let isProject: Bool
    let isDamaged: Bool

    var selectionKey: String {
        switch selection {
        case .job(let id): "job:\(id.uuidString)"
        case .project(let id): "project:\(id.uuidString)"
        }
    }
}

private extension RepairStage {
    var sceneTitle: String {
        switch self {
        case .awaitingInspection: "Kontrol bekliyor"
        case .awaitingDiagnosis: "Teşhis bekliyor"
        case .awaitingPart: "Parça bekliyor"
        case .readyForRepair: "Tamir bekliyor"
        case .awaitingPrice: "Teslime hazır"
        }
    }
}

private extension ProjectCarStage {
    var sceneTitle: String {
        switch self {
        case .awaitingRepair: "Proje • restorasyon"
        case .readyForSale: "Proje • satışa hazır"
        case .listed: "Proje • ilanda"
        }
    }
}

private extension SKColor {
    convenience init(hex: String) {
        let value = UInt64(hex, radix: 16) ?? 0xD68A36
        self.init(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }
}

struct GarageSceneView: View {
    let state: GameState
    let catalog: ContentCatalog
    @Binding var selection: WorkshopVehicleSelection?
    @State private var visiblePage = 0

    init(state: GameState, catalog: ContentCatalog, selection: Binding<WorkshopVehicleSelection?>) {
        self.state = state
        self.catalog = catalog
        _selection = selection
    }

    var body: some View {
        VStack(spacing: 0) {
            vehicleStatusBar
            Group {
                if vehicles.isEmpty {
                    GarageVehiclePage(state: state, catalog: catalog, vehicle: nil, selection: $selection)
                } else {
                    vehiclePager
                }
            }
        }
        .onChange(of: state.revision) { _, _ in
            visiblePage = min(visiblePage, max(0, vehicles.count - 1))
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(sceneDescription)
    }

    private var vehicleStatusBar: some View {
        HStack(spacing: 10) {
            Label("Aktif Araç \(vehicles.count)/\(shopCapacity)", systemImage: "car.2.fill")
                .accessibilityLabel("Dükkânda \(vehicles.count) aktif araç var. Kapasite \(shopCapacity) araç.")
            Spacer(minLength: 8)
            if vehicles.count > 1 {
                Label("\(visiblePage + 1)/\(vehicles.count) • Kaydır", systemImage: "arrow.left.and.right")
                    .accessibilityLabel("Araç \(visiblePage + 1) / \(vehicles.count), yana kaydır")
            }
        }
        .font(.caption.bold().monospacedDigit())
        .padding(.horizontal, 12)
        .frame(height: 36)
        .foregroundStyle(.white)
        .background(.black.opacity(0.78))
    }

    private var shopCapacity: Int {
        catalog.shopLevel(state.shopLevel)?.capacity ?? 1
    }

    private var vehicles: [WorkshopVehicleSelection] {
        var entries: [(vehicle: WorkshopVehicleSelection, minute: Int, order: Int)] = []
        for (index, job) in state.activeJobs.enumerated() {
            entries.append((.job(job.id), job.acceptedAtMinute, index))
        }
        let offset = state.activeJobs.count
        for (index, project) in state.projectCars.enumerated() {
            entries.append((.project(project.id), project.purchasedAtMinute, offset + index))
        }
        return entries.sorted {
            $0.minute == $1.minute ? $0.order < $1.order : $0.minute < $1.minute
        }.map(\.vehicle)
    }

    @ViewBuilder
    private var vehiclePager: some View {
        #if os(iOS)
        pager.tabViewStyle(.page(indexDisplayMode: vehicles.count > 1 ? .always : .never))
        #else
        pager
        #endif
    }

    private var pager: some View {
        TabView(selection: $visiblePage) {
            ForEach(Array(vehicles.enumerated()), id: \.element.id) { index, vehicle in
                GarageVehiclePage(
                    state: state,
                    catalog: catalog,
                    vehicle: vehicle,
                    selection: $selection
                )
                .tag(index)
            }
        }
        .onChange(of: visiblePage) { _, _ in selection = nil }
    }

    private var sceneDescription: String {
        let jobCount = state.activeJobs.count
        let projectCount = state.projectCars.count
        if jobCount + projectCount == 0 { return "Tamirhanedeki liftler boş." }
        return "Tamirhanede \(jobCount) müşteri aracı ve \(projectCount) proje aracı bulunuyor. İşlem yapmak için araç seç."
    }
}

private struct GarageVehiclePage: View {
    let state: GameState
    let catalog: ContentCatalog
    let vehicle: WorkshopVehicleSelection?
    @Binding var selection: WorkshopVehicleSelection?
    @State private var scene: WorkshopScene

    init(
        state: GameState,
        catalog: ContentCatalog,
        vehicle: WorkshopVehicleSelection?,
        selection: Binding<WorkshopVehicleSelection?>
    ) {
        self.state = state
        self.catalog = catalog
        self.vehicle = vehicle
        _selection = selection
        let filtered = Self.filteredState(state, vehicle: vehicle)
        let binding = selection
        _scene = State(initialValue: WorkshopScene(
            size: CGSize(width: 900, height: 460),
            state: filtered,
            catalog: catalog,
            selection: selection.wrappedValue
        ) { binding.wrappedValue = $0 })
    }

    var body: some View {
        SpriteView(scene: scene)
            .onAppear { refresh() }
            .onChange(of: state.revision) { _, _ in refresh() }
            .onChange(of: selection) { _, _ in refresh() }
    }

    private func refresh() {
        scene.update(state: Self.filteredState(state, vehicle: vehicle), selection: selection)
    }

    private static func filteredState(_ state: GameState, vehicle: WorkshopVehicleSelection?) -> GameState {
        var result = state
        switch vehicle {
        case .job(let id):
            result.activeJobs = state.activeJobs.filter { $0.id == id }
            result.projectCars = []
        case .project(let id):
            result.activeJobs = []
            result.projectCars = state.projectCars.filter { $0.id == id }
        case nil:
            result.activeJobs = []
            result.projectCars = []
        }
        return result
    }
}
