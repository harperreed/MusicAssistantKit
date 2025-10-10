// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MusicAssistantKit",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
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
        .testTarget(
            name: "MusicAssistantKitTests",
            dependencies: ["MusicAssistantKit"]
        ),
    ]
)
