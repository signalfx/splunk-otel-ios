// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SplunkLogger",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "SplunkLogger",
            targets: ["SplunkLogger"]
        )
    ],
    targets: [
        .target(
            name: "SplunkLogger"
        ),
        .testTarget(
            name: "SplunkLoggerTests",
            dependencies: ["SplunkLogger"]
        )
    ]
)
