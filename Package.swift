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
        .package(name: "opentelemetry-swift", url:"https://github.com/open-telemetry/opentelemetry-swift", from: "1.0.2"),
	.package(url: "https://github.com/devicekit/DeviceKit.git", from: "4.0.0"),
    ],
    targets: [
        .target(
            name: "SplunkOtel",
            dependencies: [
		.product(name: "libOpenTelemetryApi", package:"opentelemetry-swift"),
		.product(name: "libOpenTelemetrySdk", package:"opentelemetry-swift"),
		.product(name: "libStdoutExporter", package:"opentelemetry-swift"),
		.product(name: "libZipkinExporter", package:"opentelemetry-swift"),
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
