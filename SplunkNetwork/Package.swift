// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SplunkNetwork",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SplunkNetwork",
            targets: ["SplunkNetwork"]),
    ],
    dependencies: [
        .package(name: "SplunkSharedProtocols", path: "../SplunkSharedProtocols"),
        .package(name: "SplunkOpenTelemetry", path: "../SplunkOpenTelemetry")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SplunkNetwork",
            dependencies: [
                "SplunkSharedProtocols",
                "SplunkOpenTelemetry"
            ]),
        .testTarget(
            name: "SplunkNetworkTests",
            dependencies: ["SplunkNetwork"]),
    ]
)
