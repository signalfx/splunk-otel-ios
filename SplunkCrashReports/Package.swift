// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SplunkCrashReports",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SplunkCrashReports",
            targets: ["SplunkCrashReports"]),
    ],
    dependencies: [
        .package(name: "ADCrashReporter", path: "../ADCrashReporter"),
        .package(name: "SplunkOpenTelemetry", path: "../SplunkOpenTelemetry"),
        .package(name: "SplunkSharedProtocols", path: "../SplunkSharedProtocols")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SplunkCrashReports",
            dependencies: [
                .product(name: "ADCrashReporter", package: "ADCrashReporter"),
                .product(name: "SplunkOpenTelemetry", package: "SplunkOpenTelemetry"),
                .product(name: "SplunkSharedProtocols", package: "SplunkSharedProtocols")
            ],
            cSettings: [
                .define("PLCR_PRIVATE"),
                .define("PLCF_RELEASE_BUILD"),
                .define("PLCRASHREPORTER_PREFIX", to: "APPD"),
                .headerSearchPath("Dependencies/protobuf-c")
            ]),
        .testTarget(
            name: "SplunkCrashReportsTests",
            dependencies: ["SplunkCrashReports", "SplunkSharedProtocols"]),
    ]
)
