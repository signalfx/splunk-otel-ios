// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SplunkCustomTracking",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "SplunkCustomTracking",
            targets: ["SplunkCustomTracking"]
        )
    ],
    dependencies: [
        .package(name: "SplunkSharedProtocols", path: "../SplunkSharedProtocols")
    ],
    targets: [
        .target(
            name: "SplunkCustomTracking",
            dependencies: [
                "SplunkSharedProtocols"
            ]
        ),
        .testTarget(
            name: "SplunkCustomTrackingTests",
            dependencies: ["SplunkCustomTracking"]
        )
    ]
)
