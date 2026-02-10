// tools/xcframework/smoke-test/Project.swift
//
// Tuist manifest for the XCFramework smoke test app.
//
// This project creates a minimal iOS app that links against ALL built
// xcframeworks to verify:
//   1. All frameworks can be found and linked
//   2. Module imports resolve correctly
//   3. Basic runtime initialization works
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

/// Directory containing all xcframeworks for distribution.
///
/// After `make build`, this contains Agent modules, OTel, PLCrash, and Cisco SR.
let xcfwDir = "../output/xcframeworks"

/// Agent modules (built by `make build-agent`).
let agentFrameworks = [
    "SplunkAgent",
    "SplunkAgentObjC",
    "SplunkCommon",
    "SplunkNavigation",
    "SplunkNetwork",
    "SplunkNetworkMonitor",
    "SplunkSlowFrameDetector",
    "SplunkCrashReports",
    "SplunkOpenTelemetry",
    "SplunkOpenTelemetryBackgroundExporter",
    "SplunkInteractions",
    "SplunkAppStart",
    "SplunkAppState",
    "SplunkWebView",
    "SplunkCustomTracking",
    "SplunkSessionReplayProxy"
]

/// OpenTelemetry (built by `make build-otel`).
let otelFrameworks = [
    "OpenTelemetryApi",
    "OpenTelemetrySdk"
]

/// PLCrashReporter (built by `make build-plcrash`).
let crashFrameworks = [
    "CrashReporter"
]

/// Cisco Session Replay (downloaded by `make populate-deps`).
let ciscoFrameworks = [
    "CiscoLogger",
    "CiscoEncryption",
    "CiscoSwizzling",
    "CiscoInteractions",
    "CiscoDiskStorage",
    "CiscoSessionReplay",
    "CiscoInstanceManager",
    "CiscoRuntimeCache"
]

/// All frameworks combined.
let allFrameworks = agentFrameworks + otelFrameworks + crashFrameworks + ciscoFrameworks


// ---------------------------------------------------------------------------
// MARK: - Project
// ---------------------------------------------------------------------------

let project = Project(
    name: "XCFrameworkSmokeTest",
    settings: .settings(
        configurations: [
            .debug(name: "Debug", settings: [:]),
            .release(name: "Release", settings: [:])
        ]
    ),
    targets: [
        .target(
            name: "XCFrameworkSmokeTest",
            destinations: [.iPhone, .iPad],
            product: .app,
            bundleId: "com.splunk.rum.xcframework-smoke-test",
            deploymentTargets: .iOS("14.0"),
            sources: ["Sources/**"],
            dependencies: allFrameworks.map { name in
                .xcframework(path: "\(xcfwDir)/\(name).xcframework")
            }
        )
    ]
)
