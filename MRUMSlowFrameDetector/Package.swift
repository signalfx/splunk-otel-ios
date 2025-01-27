// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MRUMSlowFrameDetector",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13)
    ],
    products: [
        .library(
            name: "MRUMSlowFrameDetector",
            targets: [
                "MRUMSlowFrameDetector"
            ]
        )
    ],
    dependencies: [
        .package(name: "MRUMSharedProtocols",
                 path: "../MRUMSharedProtocols"),
        .package(name: "SplunkOpenTelemetry",
                 path: "../SplunkOpenTelemetry")
    ],
    targets: [
        .target(
            name: "MRUMSlowFrameDetector",
            dependencies: [
                .product(name: "MRUMSharedProtocols",
                         package: "MRUMSharedProtocols"),
                .product(name: "SplunkOpenTelemetry",
                         package: "SplunkOpenTelemetry")
            ]
        ),
        .testTarget(
            name: "MRUMSlowFrameDetectorTests",
            dependencies: ["MRUMSlowFrameDetector"]
        )
    ]
)
