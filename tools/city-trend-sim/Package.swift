// swift-tools-version: 6.0
import PackageDescription

// The city-trend outcome explorer (2026-10-17): runs many worlds through the game's own rules
// (MPCCityTrendWorld) to see what chapter-one endings players' choices can lead to.
let package = Package(
    name: "CityTrendSim",
    platforms: [.macOS(.v13)],
    dependencies: [.package(path: "../../mistport-ios/MistportCombatCore")],
    targets: [.executableTarget(name: "CityTrendSim",
                                dependencies: [.product(name: "MistportCombatCore", package: "MistportCombatCore")])]
)
