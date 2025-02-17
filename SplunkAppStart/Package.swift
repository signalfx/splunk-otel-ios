// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SplunkAppStart",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13)
    ],
    products: [
        .library(
            name: "SplunkAppStart",
            targets: ["SplunkAppStart"]
        )
    ],
    dependencies: [
        .package(name: "SplunkSharedProtocols", path: "../SplunkSharedProtocols"),
        .package(name: "SplunkLogger", path: "../SplunkLogger"),
        .package(name: "SplunkOpenTelemetry", path: "../SplunkOpenTelemetry")
    ],
    targets: [
        .target(
            name: "SplunkAppStart",
            dependencies: [
                "SplunkSharedProtocols",
                "SplunkLogger",
                "SplunkOpenTelemetry"
            ]
        ),
        .testTarget(
            name: "SplunkAppStartTests",
            dependencies: [
                "SplunkAppStart",
                "SplunkSharedProtocols",
                "SplunkLogger",
                "SplunkOpenTelemetry"
            ]
        )
    ]
)
