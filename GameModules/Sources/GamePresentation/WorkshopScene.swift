import GameDomain
import SpriteKit
import SwiftUI

@MainActor
public final class WorkshopScene: SKScene {
    public init(size: CGSize, state: GameState, catalog: ContentCatalog) {
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = SKColor(red: 0.08, green: 0.09, blue: 0.10, alpha: 1)
        build(state: state, catalog: catalog)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { nil }

    private func build(state: GameState, catalog: ContentCatalog) {
        removeAllChildren()
        addFloor()
        addBackWall(shopLevel: state.shopLevel, themeID: state.selectedThemeID)
        addLift()
        if let job = state.activeJobs.first,
           let vehicle = catalog.vehicle(id: job.vehicleID) {
            addCar(name: vehicle.name, color: SKColor(hex: vehicle.accentHex))
        } else if let project = state.projectCars.first,
                  let vehicle = catalog.vehicle(id: project.vehicleID) {
            addCar(name: vehicle.name, color: SKColor(hex: vehicle.accentHex), damaged: project.stage == .awaitingRepair)
        } else {
            addEmptyLabel()
        }
        addAmbientAnimation()
    }

    private func addFloor() {
        let floor = SKShapeNode(rect: CGRect(x: 0, y: 0, width: size.width, height: size.height * 0.58))
        floor.fillColor = SKColor(red: 0.23, green: 0.24, blue: 0.22, alpha: 1)
        floor.strokeColor = .clear
        floor.position = CGPoint(x: 0, y: 0)
        addChild(floor)

        for index in 0..<7 {
            let line = SKShapeNode(rectOf: CGSize(width: size.width * 1.3, height: 1))
            line.strokeColor = .clear
            line.fillColor = SKColor(white: 0.32, alpha: 0.45)
            line.zRotation = -.pi / 10
            line.position = CGPoint(x: size.width / 2, y: CGFloat(index) * 22)
            addChild(line)
        }
    }

    private func addBackWall(shopLevel: Int, themeID: String) {
        let wall = SKShapeNode(rect: CGRect(x: 0, y: size.height * 0.58, width: size.width, height: size.height * 0.42))
        wall.fillColor = themeID == "copper"
            ? SKColor(red: 0.24, green: 0.14, blue: 0.10, alpha: 1)
            : SKColor(red: 0.16, green: 0.18, blue: 0.18, alpha: 1)
        wall.strokeColor = .clear
        addChild(wall)

        let sign = SKShapeNode(rectOf: CGSize(width: 178, height: 38), cornerRadius: 7)
        sign.fillColor = themeID == "copper"
            ? SKColor(red: 0.72, green: 0.37, blue: 0.20, alpha: 1)
            : SKColor(red: 0.89, green: 0.55, blue: 0.20, alpha: 1)
        sign.strokeColor = SKColor(white: 0.95, alpha: 0.35)
        sign.position = CGPoint(x: size.width / 2, y: size.height - 38)
        addChild(sign)

        let title = SKLabelNode(text: shopLevel == 1 ? "USTANIN YERİ" : "USTANIN YERİ • \(shopLevel)")
        title.fontName = "AvenirNext-Heavy"
        title.fontSize = 16
        title.fontColor = SKColor(red: 0.12, green: 0.10, blue: 0.08, alpha: 1)
        title.verticalAlignmentMode = .center
        sign.addChild(title)

        let shelf = SKShapeNode(rectOf: CGSize(width: 92, height: 10), cornerRadius: 2)
        shelf.fillColor = SKColor(red: 0.29, green: 0.18, blue: 0.10, alpha: 1)
        shelf.strokeColor = .clear
        shelf.position = CGPoint(x: 62, y: size.height * 0.66)
        addChild(shelf)
        for offset in [-30, -10, 12, 31] {
            let can = SKShapeNode(rectOf: CGSize(width: 12, height: 22), cornerRadius: 2)
            can.fillColor = offset.isMultiple(of: 2) ? .systemRed : .systemBlue
            can.strokeColor = .clear
            can.position = CGPoint(x: CGFloat(offset), y: 15)
            shelf.addChild(can)
        }
    }

    private func addLift() {
        for x in [size.width * 0.22, size.width * 0.78] {
            let post = SKShapeNode(rectOf: CGSize(width: 14, height: 106), cornerRadius: 3)
            post.fillColor = SKColor(red: 0.76, green: 0.33, blue: 0.18, alpha: 1)
            post.strokeColor = .clear
            post.position = CGPoint(x: x, y: size.height * 0.37)
            addChild(post)
        }
    }

    private func addCar(name: String, color: SKColor, damaged: Bool = false) {
        let car = SKNode()
        car.position = CGPoint(x: size.width / 2, y: size.height * 0.34)
        car.name = "car"

        let bodyPath = CGMutablePath()
        bodyPath.move(to: CGPoint(x: -105, y: -18))
        bodyPath.addLine(to: CGPoint(x: -88, y: 24))
        bodyPath.addLine(to: CGPoint(x: -45, y: 38))
        bodyPath.addLine(to: CGPoint(x: 42, y: 38))
        bodyPath.addLine(to: CGPoint(x: 91, y: 20))
        bodyPath.addLine(to: CGPoint(x: 108, y: -18))
        bodyPath.closeSubpath()
        let body = SKShapeNode(path: bodyPath)
        body.fillColor = color
        body.strokeColor = SKColor(white: 0.9, alpha: 0.35)
        body.lineWidth = 2
        car.addChild(body)

        let window = SKShapeNode(rectOf: CGSize(width: 76, height: 27), cornerRadius: 7)
        window.fillColor = SKColor(red: 0.19, green: 0.28, blue: 0.32, alpha: 1)
        window.strokeColor = .clear
        window.position = CGPoint(x: 0, y: 22)
        car.addChild(window)

        for x in [-68.0, 68.0] {
            let wheel = SKShapeNode(circleOfRadius: 20)
            wheel.fillColor = SKColor(white: 0.08, alpha: 1)
            wheel.strokeColor = SKColor(white: 0.5, alpha: 1)
            wheel.lineWidth = 5
            wheel.position = CGPoint(x: x, y: -22)
            car.addChild(wheel)
        }

        if damaged {
            let damage = SKLabelNode(text: "⚠︎")
            damage.fontSize = 30
            damage.position = CGPoint(x: 75, y: 2)
            car.addChild(damage)
        }

        let label = SKLabelNode(text: name)
        label.fontName = "AvenirNext-DemiBold"
        label.fontSize = 13
        label.fontColor = .white
        label.position = CGPoint(x: 0, y: -58)
        car.addChild(label)
        addChild(car)
    }

    private func addEmptyLabel() {
        let label = SKLabelNode(text: "Lift boş • müşteri seç")
        label.fontName = "AvenirNext-Medium"
        label.fontSize = 15
        label.fontColor = SKColor(white: 0.76, alpha: 1)
        label.position = CGPoint(x: size.width / 2, y: size.height * 0.31)
        addChild(label)
    }

    private func addAmbientAnimation() {
        guard let car = childNode(withName: "car") else { return }
        let up = SKAction.moveBy(x: 0, y: 2, duration: 1.2)
        up.timingMode = .easeInEaseOut
        car.run(.repeatForever(.sequence([up, up.reversed()])))
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

    var body: some View {
        GeometryReader { proxy in
            SpriteView(scene: WorkshopScene(size: proxy.size, state: state, catalog: catalog))
                .ignoresSafeArea(edges: .horizontal)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(sceneDescription)
        }
    }

    private var sceneDescription: String {
        if let job = state.activeJobs.first, let vehicle = catalog.vehicle(id: job.vehicleID) {
            return "Tamirhanede \(vehicle.name) araç bulunuyor."
        }
        if let project = state.projectCars.first, let vehicle = catalog.vehicle(id: project.vehicleID) {
            return "Tamirhanede ihale aracı \(vehicle.name) bulunuyor."
        }
        return "Tamirhane şu anda boş."
    }
}
