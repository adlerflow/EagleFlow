// swift-tools-version:6.0

import PackageDescription

let package = Package(
    name: "EagleFlow",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "EagleFlow",
            targets: ["EagleFlow"]),
        .library(
            name: "EagleFlowUtils",
            targets: ["EagleFlowUtils"]),
        .executable(
            name: "EagleFlowCLI",
            targets: ["EagleFlowCLI"]),
        .executable(
            name: "EagleFlowGUI", 
            targets: ["EagleFlowGUI"])
    ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.8.2"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.42.0"),
        .package(url: "https://github.com/apple/swift-nio-extras.git", from: "1.18.0"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "2.3.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.4.2"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.1.0"),
        .package(url: "https://github.com/apple/swift-signal-handling.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "EagleFlow",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "NIOConcurrencyHelpers", package: "swift-nio"),
                .product(name: "NIOFoundationCompat", package: "swift-nio"),
                .product(name: "NIOExtras", package: "swift-nio-extras"),
                .product(name: "Logging", package: "swift-log")
            ]),
        .target(
            name: "EagleFlowUtils",
            dependencies: [
                "EagleFlow"
            ]),
        .executableTarget(
            name: "EagleFlowCLI",
            dependencies: [
                "EagleFlow",
                "EagleFlowUtils",
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Signals", package: "swift-signal-handling")
            ]),
        .executableTarget(
            name: "EagleFlowGUI",
            dependencies: [
                "EagleFlow",
                "EagleFlowUtils"
            ]),
        .testTarget(
            name: "EagleFlowTests",
            dependencies: ["EagleFlow"]),
        .testTarget(
            name: "EagleFlowUtilsTests",
            dependencies: ["EagleFlowUtils"]),
    ]
)