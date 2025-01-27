// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SplunkSlowFrameDetector",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13)
    ],
    products: [
        .library(
            name: "SplunkSlowFrameDetector",
            targets: [
                "SplunkSlowFrameDetector"
            ]
        )
    ],
    dependencies: [
        .package(name: "SplunkSharedProtocols",
                 path: "../SplunkSharedProtocols"),
        .package(name: "SplunkOpenTelemetry",
                 path: "../SplunkOpenTelemetry")
    ],
    targets: [
        .target(
            name: "SplunkSlowFrameDetector",
            dependencies: [
                .product(name: "SplunkSharedProtocols",
                         package: "SplunkSharedProtocols"),
                .product(name: "SplunkOpenTelemetry",
                         package: "SplunkOpenTelemetry")
            ]
        ),
        .testTarget(
            name: "SplunkSlowFrameDetectorTests",
            dependencies: ["SplunkSlowFrameDetector"]
        )
    ]
)
