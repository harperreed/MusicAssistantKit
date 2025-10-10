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
    ],
    targets: [
        .target(
            name: "MusicAssistantKit"
        ),
        .testTarget(
            name: "MusicAssistantKitTests",
            dependencies: ["MusicAssistantKit"]
        ),
    ]
)
