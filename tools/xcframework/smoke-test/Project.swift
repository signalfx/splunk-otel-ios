// tools/xcframework/smoke-test/Project.swift
//
// Tuist manifest for the XCFramework smoke test app.
//
// This project creates a minimal app whose framework search path contains
// only shipped xcframeworks. It verifies binary customers do not need any
// internal Splunk or Cisco frameworks.
//
// Prerequisites:
//   - All xcframeworks must be built in ../output/xcframeworks/
//   - Run `tuist generate` from this directory
//
// Usage:
//   cd tools/xcframework/smoke-test
//   tuist generate --no-open
//   xcodebuild build -workspace XCFrameworkSmokeTest.xcworkspace \
//       -scheme XCFrameworkSmokeTest \
//       -destination "generic/platform=iOS Simulator"

import ProjectDescription

// ---------------------------------------------------------------------------
// MARK: - XCFramework Paths
// ---------------------------------------------------------------------------

/// Directory containing shipped xcframeworks for distribution.
let xcfwDir = "../output/xcframeworks"

let shippedFrameworks = [
    "SplunkAgent",
    "SplunkAgentObjC",
    "OpenTelemetryApi",
    "OpenTelemetrySdk"
]

let noCrashReporterCondition = PlatformCondition.when([.ios, .tvos, .catalyst])


// ---------------------------------------------------------------------------
// MARK: - Project
// ---------------------------------------------------------------------------

let project = Project(
    name: "XCFrameworkSmokeTest",
    settings: .settings(
        base: [
            "SUPPORTS_MACCATALYST": "YES"
        ],
        configurations: [
            .debug(name: "Debug", settings: [:]),
            .release(name: "Release", settings: [:])
        ]
    ),
    targets: [
        .target(
            name: "XCFrameworkSmokeTest",
            destinations: [.iPhone, .iPad, .appleTv, .appleVision, .macCatalyst],
            product: .app,
            bundleId: "com.splunk.rum.xcframework-smoke-test",
            sources: ["Sources/**"],
            dependencies: shippedFrameworks.map { name in
                .xcframework(path: "\(xcfwDir)/\(name).xcframework")
            } + [
                .xcframework(path: "\(xcfwDir)/CrashReporter.xcframework", condition: noCrashReporterCondition)
            ]
        )
    ]
)
