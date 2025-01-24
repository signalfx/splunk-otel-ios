// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MRUMCustomData",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "MRUMCustomData",
            targets: ["MRUMCustomData"])
    ],
    dependencies: [
        .package(name: "MRUMSharedProtocols", path: "../MRUMSharedProtocols")
    ],
    targets: [
        .target(
            name: "MRUMCustomData",
            dependencies: [
                "MRUMSharedProtocols"
            ]),
        .testTarget(
            name: "MRUMCustomDataTests",
            dependencies: ["MRUMCustomData"])
    ]
)
