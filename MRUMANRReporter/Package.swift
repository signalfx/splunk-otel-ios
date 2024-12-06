// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MRUMANRReporter",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13)
    ],
    products: [
        .library(
            name: "MRUMANRReporter",
            targets: ["MRUMANRReporter"])
    ],
    dependencies: [
        .package(name: "MRUMSharedProtocols", path: "../MRUMSharedProtocols")
    ],
    targets: [
        .target(
            name: "MRUMANRReporter",
            dependencies: [
                "MRUMSharedProtocols"
            ]),
        .testTarget(
            name: "MRUMANRReporterTests",
            dependencies: ["MRUMANRReporter"])
    ]
)
