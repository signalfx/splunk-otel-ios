// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SplunkANRReporter",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13)
    ],
    products: [
        .library(
            name: "SplunkANRReporter",
            targets: ["SplunkANRReporter"])
    ],
    dependencies: [
        .package(name: "SplunkSharedProtocols", path: "../SplunkSharedProtocols")
    ],
    targets: [
        .target(
            name: "SplunkANRReporter",
            dependencies: [
                "SplunkSharedProtocols"
            ]),
        .testTarget(
            name: "SplunkANRReporterTests",
            dependencies: ["SplunkANRReporter"])
    ]
)
