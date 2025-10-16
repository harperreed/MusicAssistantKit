// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MusicAssistantKit",
    platforms: [
        .iOS(.v15),
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "MusicAssistantKit",
            targets: ["MusicAssistantKit"]
        ),
        .executable(
            name: "ma-control",
            targets: ["MAControl"]
        ),
        .executable(
            name: "ma-search",
            targets: ["MASearch"]
        ),
        .executable(
            name: "ma-monitor",
            targets: ["MAMonitor"]
        ),
        .executable(
            name: "ma-status",
            targets: ["MAStatus"]
        ),
        .executable(
            name: "ma-api-discovery",
            targets: ["MAAPIDiscovery"]
        ),
        .executable(
            name: "ma-stream",
            targets: ["MAStream"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-testing.git", from: "0.10.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0"),
    ],
    targets: [
        .target(
            name: "MusicAssistantKit"
        ),
        .executableTarget(
            name: "MAControl",
            dependencies: ["MusicAssistantKit"]
        ),
        .executableTarget(
            name: "MASearch",
            dependencies: ["MusicAssistantKit"]
        ),
        .executableTarget(
            name: "MAMonitor",
            dependencies: ["MusicAssistantKit"]
        ),
        .executableTarget(
            name: "MAStatus",
            dependencies: ["MusicAssistantKit"]
        ),
        .executableTarget(
            name: "MAAPIDiscovery",
            dependencies: ["MusicAssistantKit"]
        ),
        .target(
            name: "MAStreamLib",
            dependencies: [
                "MusicAssistantKit",
            ]
        ),
        .executableTarget(
            name: "MAStream",
            dependencies: [
                "MAStreamLib",
                "MusicAssistantKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "MusicAssistantKitTests",
            dependencies: [
                "MusicAssistantKit",
                .product(name: "Testing", package: "swift-testing"),
            ]
        ),
        .testTarget(
            name: "MAStreamTests",
            dependencies: [
                "MAStreamLib",
                "MusicAssistantKitTests",
            ]
        ),
    ]
)
