// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ContextWardenKit",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "ContextWardenKit",
            targets: ["ContextWardenKit"]),
    ],
    dependencies: [
        // No third-party dependencies as per requirements
    ],
    targets: [
        .target(
            name: "ContextWardenKit",
            dependencies: []),
        .testTarget(
            name: "ContextWardenKitTests",
            dependencies: ["ContextWardenKit"]),
    ]
)
