// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "SplunkOtel",
    platforms: [
        .iOS(.v11),
        .macOS(.v10_13)
    ],
    products: [
        .library(name: "SplunkOtel", targets: ["SplunkOtel"])
    ],
    dependencies: [
        .package(url: "https://github.com/open-telemetry/opentelemetry-swift", .exact("1.2.0")),
        .package(url: "https://github.com/devicekit/DeviceKit.git", from: "4.0.0"),
    ],
    targets: [
        .target(
            name: "SplunkOtel",
            dependencies: [
                .product(name: "OpenTelemetryApi", package:"opentelemetry-swift"),
                .product(name: "OpenTelemetrySdk", package:"opentelemetry-swift"),
                .product(name: "StdoutExporter", package:"opentelemetry-swift"),
                .product(name: "ZipkinExporter", package:"opentelemetry-swift"),
                .product(name: "DeviceKit", package: "DeviceKit")
            ],
            path: "SplunkRumWorkspace/SplunkRum",
            exclude: [
                "SplunkRumTests",
                "SplunkRumDiskExportTests",
                "SplunkRum/SplunkRum.h",
                "SplunkRum/Info.plist"
            ],
            sources: [
                "SplunkRum",
            ]
        )
    ]
)
