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
        .package(name: "opentelemetry-swift", url:"https://github.com/open-telemetry/opentelemetry-swift", from: "1.0.0"),
        .package(name: "PLCrashReporter", url:"https://github.com/microsoft/plcrashreporter", from: "1.8.1"),
	.package(url: "https://github.com/devicekit/DeviceKit.git", from: "4.3.0"),
    ],
    targets: [
        .target(
            name: "SplunkRum",
            dependencies: [
		.product(name: "libOpenTelemetryApi", package:"opentelemetry-swift"),
		.product(name: "libOpenTelemetrySdk", package:"opentelemetry-swift"),
		.product(name: "libStdoutExporter", package:"opentelemetry-swift"),
		.product(name: "libZipkinExporter", package:"opentelemetry-swift"),
		.product(name: "CrashReporter", package: "PLCrashReporter"),
		.product(name: "DeviceKit", package: "DeviceKit")
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
