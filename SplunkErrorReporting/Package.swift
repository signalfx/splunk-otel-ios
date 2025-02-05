// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SplunkErrorReporting",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "SplunkErrorReporting",
            targets: ["SplunkErrorReporting"]
        )
    ],
    dependencies: [
        .package(name: "SplunkSharedProtocols", path: "../SplunkSharedProtocols")
    ],
    targets: [
        .target(
            name: "SplunkErrorReporting",
            dependencies: [
                "SplunkSharedProtocols"
            ]
        ),
        .testTarget(
            name: "SplunkErrorReportingTests",
            dependencies: ["SplunkErrorReporting"]
        )
    ]
)
