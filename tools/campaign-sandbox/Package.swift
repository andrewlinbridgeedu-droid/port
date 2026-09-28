// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "MistportCampaignSandbox", platforms: [.macOS(.v14)], dependencies: [.package(path: "../../mistport-ios/MistportCombatCore")], targets: [.executableTarget(name: "MistportCampaignSandbox", dependencies: [.product(name: "MistportCombatCore", package: "MistportCombatCore")], path: "Sources")])
