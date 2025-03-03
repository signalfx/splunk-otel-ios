// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SplunkOpenTelemetry",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .visionOS(.v1)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SplunkOpenTelemetry",
            targets: [
                "SplunkOpenTelemetry",
            ]),
    ],
    dependencies: [
        .package(name: "SplunkOpenTelemetryBackgroundExporter", path: "../SplunkOpenTelemetryBackgroundExporter"),
        .package(name: "SplunkLogger", path: "../SplunkLogger"),
        .package(
            url: "https://github.com/open-telemetry/opentelemetry-swift",
            exact: "1.12.1"
        )
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SplunkOpenTelemetry",
            dependencies: [
                "SplunkOpenTelemetryBackgroundExporter",
                "SplunkLogger",
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift"),
                .product(name: "URLSessionInstrumentation", package: "opentelemetry-swift"),
                .product(name: "ResourceExtension", package: "opentelemetry-swift"),
                .product(name: "SignPostIntegration", package: "opentelemetry-swift"),
                .product(name: "StdoutExporter", package: "opentelemetry-swift"),
                .product(name: "ZipkinExporter", package: "opentelemetry-swift")
            ]),

        .testTarget(
            name: "SplunkOpenTelemetryTests",
            dependencies: ["SplunkOpenTelemetry"]),
    ]
)
