// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MistportCombatCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v13)
    ],  
    products: [
        .library(name: "MistportCombatCore", targets: ["MistportCombatCore"])
    ],
    targets: [
        .target(
            name: "MistportCombatCore",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "MistportCombatCoreTests",
            dependencies: ["MistportCombatCore"],
            resources: [.process("Resources")]
        )
    ]
)
