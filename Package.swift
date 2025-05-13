// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

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
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "EagleFlow",
            targets: ["EagleFlow"]),
        .library(
            name: "EagleFlowUtils",
            targets: ["EagleFlowUtils"]),
        .executable(
            name: "EagleFlowCLI",
            targets: ["EagleFlowCLI"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.8.2"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "EagleFlow",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk")
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