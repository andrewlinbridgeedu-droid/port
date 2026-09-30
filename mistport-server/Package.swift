// swift-tools-version: 6.0

import PackageDescription

// Shared-server technical sample (M0): one authoritative service with a transactional
// SQLite ledger and server-side battle replay through MistportCombatCore.
// Hummingbird is pinned to 2.17, the last release whose manifest builds with Swift 6.0.
let package = Package(
    name: "MistportServer",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MistportLedger", targets: ["MistportLedger"]),
        .executable(name: "mistport-server", targets: ["MistportServerApp"]),
    ],
    dependencies: [
        .package(path: "../mistport-ios/MistportCombatCore"),
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", .upToNextMinor(from: "2.17.0")),
        .package(url: "https://github.com/apple/swift-crypto.git", "3.0.0"..<"4.0.0"),
        .package(url: "https://github.com/apple/swift-http-types.git", from: "1.0.0"),
    ],
    targets: [
        .systemLibrary(name: "CSQLite", path: "Sources/CSQLite", providers: [.apt(["libsqlite3-dev"]), .brew(["sqlite"])]),
        .target(name: "MistportLedger", dependencies: [
            "CSQLite",
            .product(name: "MistportCombatCore", package: "MistportCombatCore"),
            .product(name: "Crypto", package: "swift-crypto"),
        ]),
        .target(name: "MistportServer", dependencies: [
            "MistportLedger",
            .product(name: "Hummingbird", package: "hummingbird"),
            .product(name: "HTTPTypes", package: "swift-http-types"),
        ]),
        .executableTarget(name: "MistportServerApp", dependencies: ["MistportServer"]),
        .testTarget(name: "MistportLedgerTests", dependencies: [
            "MistportLedger",
            .product(name: "MistportCombatCore", package: "MistportCombatCore"),
        ]),
        .testTarget(name: "MistportServerTests", dependencies: [
            "MistportServer",
            "MistportLedger",
            .product(name: "MistportCombatCore", package: "MistportCombatCore"),
            .product(name: "HummingbirdTesting", package: "hummingbird"),
            .product(name: "HTTPTypes", package: "swift-http-types"),
        ]),
    ]
)
