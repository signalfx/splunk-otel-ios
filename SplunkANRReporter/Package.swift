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
        .package(name: "MRUMSharedProtocols", path: "../MRUMSharedProtocols")
    ],
    targets: [
        .target(
            name: "SplunkANRReporter",
            dependencies: [
                "MRUMSharedProtocols"
            ]),
        .testTarget(
            name: "SplunkANRReporterTests",
            dependencies: ["SplunkANRReporter"])
    ]
)
