// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProgressionSim",
    platforms: [.macOS(.v13)],
    dependencies: [.package(path: "../../mistport-ios/MistportCombatCore")],
    targets: [.executableTarget(name: "ProgressionSim",
                                dependencies: [.product(name: "MistportCombatCore", package: "MistportCombatCore")])]
)
