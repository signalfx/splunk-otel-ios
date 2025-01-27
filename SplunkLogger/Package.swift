// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MRUMLogger",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "MRUMLogger",
            targets: ["MRUMLogger"]
        )
    ],
    targets: [
        .target(
            name: "MRUMLogger"
        ),
        .testTarget(
            name: "MRUMLoggerTests",
            dependencies: ["MRUMLogger"]
        )
    ]
)
