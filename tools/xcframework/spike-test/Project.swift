// tools/xcframework/spike-test/Project.swift
//
// Tuist manifest for the OTel xcframework smoke test.
// This creates a command-line tool target that links against the
// built OpenTelemetryApi.xcframework and OpenTelemetrySdk.xcframework
// to verify they work as expected.

import ProjectDescription

// Path to the built xcframeworks (relative to this Project.swift)
let xcframeworksDir = "../output/xcframeworks"

let project = Project(
    name: "OTelSmokeTest",
    targets: [
        .target(
            name: "OTelSmokeTest",
            destinations: [.iPhone, .iPad],
            product: .app,
            bundleId: "com.splunk.otel.smoketest",
            sources: ["SmokeTest.swift"],
            dependencies: [
                .xcframework(path: "\(xcframeworksDir)/OpenTelemetryApi.xcframework"),
                .xcframework(path: "\(xcframeworksDir)/OpenTelemetrySdk.xcframework")
            ],
            settings: .settings(
                base: [
                    "IPHONEOS_DEPLOYMENT_TARGET": "14.0"
                ]
            )
        )
    ]
)
