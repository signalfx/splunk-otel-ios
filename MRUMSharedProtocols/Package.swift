// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MRUMSharedProtocols",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "MRUMSharedProtocols",
            targets: ["MRUMSharedProtocols"]
        )
    ],
    targets: [
        .target(
            name: "MRUMSharedProtocols"
        ),
        .testTarget(
            name: "MRUMSharedProtocolsTests",
            dependencies: ["MRUMSharedProtocols"]
        )
    ]
)
