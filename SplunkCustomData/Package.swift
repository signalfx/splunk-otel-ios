// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SplunkCustomData",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "SplunkCustomData",
            targets: ["SplunkCustomData"]
        )
    ],
    dependencies: [
        .package(name: "SplunkSharedProtocols", path: "../SplunkSharedProtocols")
    ],
    targets: [
        .target(
            name: "SplunkCustomData",
            dependencies: [
                "SplunkSharedProtocols"
            ]
        ),
        .testTarget(
            name: "SplunkCustomDataTests",
            dependencies: ["SplunkCustomData"]
        )
    ]
)
