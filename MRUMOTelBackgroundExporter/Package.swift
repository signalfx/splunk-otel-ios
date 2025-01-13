// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MRUMOTelBackgroundExporter",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .visionOS(.v1)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "MRUMOTelBackgroundExporter",
            targets: [
                "MRUMOTelBackgroundExporter"
            ])
    ],
    dependencies: [
        .package(name: "MRUMLogger", path: "../MRUMLogger"),
        .package(
            url: "https://github.com/open-telemetry/opentelemetry-swift",
            exact: "1.12.1"
        )
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "MRUMOTelBackgroundExporter",
            dependencies: [
                "MRUMLogger",
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift"),
                .product(name: "OpenTelemetryProtocolExporter", package: "opentelemetry-swift")
            ]),

        .testTarget(
            name: "MRUMOTelBackgroundExporterTests",
            dependencies: ["MRUMOTelBackgroundExporter"])
    ]
)
