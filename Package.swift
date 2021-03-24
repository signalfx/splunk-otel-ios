// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "SplunkRum",
    platforms: [
        .iOS(.v11),
	.macOS(.v10_13)
    ],
    products: [
        .library(name: "SplunkRum", targets: ["SplunkRum"])
    ],
    dependencies: [
        .package(name: "opentelemetry-swift", url:"https://github.com/open-telemetry/opentelemetry-swift", from: "0.6.0"),
        .package(name: "PLCrashReporter", url:"https://github.com/microsoft/plcrashreporter", from: "1.8.1"),
    ],
    targets: [
        .target(
            name: "SplunkRum",
            dependencies: [
		.product(name: "libOpenTelemetryApi", package:"opentelemetry-swift"),
		.product(name: "libOpenTelemetrySdk", package:"opentelemetry-swift"),
		.product(name: "libStdoutExporter", package:"opentelemetry-swift"),
		.product(name: "libZipkinExporter", package:"opentelemetry-swift"),
		.product(name: "CrashReporter", package: "PLCrashReporter")
            ],
            path: "SplunkRumWorkspace/SplunkRum",
            exclude: [
		"SplunkRumTests",
		"SplunkRum/SplunkRum.h",
		"SplunkRum/Info.plist"
            ],
            sources: [
                "SplunkRum",
            ]
        )
    ]
)
