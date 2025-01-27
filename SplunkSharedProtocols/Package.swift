// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SplunkSharedProtocols",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "SplunkSharedProtocols",
            targets: ["SplunkSharedProtocols"]
        )
    ],
    targets: [
        .target(
            name: "SplunkSharedProtocols"
        ),
        .testTarget(
            name: "SplunkSharedProtocolsTests",
            dependencies: ["SplunkSharedProtocols"]
        )
    ]
)
