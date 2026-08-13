// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "OtoTamirModules",
    defaultLocalization: "tr",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "GameDomain", targets: ["GameDomain"]),
        .library(name: "GameLogic", targets: ["GameLogic"]),
        .library(name: "GameContent", targets: ["GameContent"]),
        .library(name: "GamePersistence", targets: ["GamePersistence"]),
        .library(name: "GameCommerce", targets: ["GameCommerce"]),
        .library(name: "GamePresentation", targets: ["GamePresentation"])
    ],
    targets: [
        .target(name: "GameDomain"),
        .target(name: "GameLogic", dependencies: ["GameDomain"]),
        .target(
            name: "GameContent",
            dependencies: ["GameDomain"],
            resources: [.process("Resources")]
        ),
        .target(name: "GamePersistence", dependencies: ["GameDomain"]),
        .target(name: "GameCommerce", dependencies: ["GameDomain"]),
        .target(
            name: "GamePresentation",
            dependencies: ["GameDomain", "GameLogic", "GameContent"]
        ),
        .testTarget(name: "GameLogicTests", dependencies: ["GameDomain", "GameLogic", "GameContent", "GamePersistence"]),
        .testTarget(name: "GameContentTests", dependencies: ["GameDomain", "GameContent"])
    ],
    swiftLanguageModes: [.v6]
)
