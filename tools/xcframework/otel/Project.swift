// tools/xcframework/otel/Project.swift
//
// Tuist manifest that wraps OpenTelemetry Swift Core source files into
// dynamic framework targets suitable for xcframework creation.
//
// The OTel source is expected at `vendor/opentelemetry-swift-core/`
// (cloned by the build script before `tuist generate`).
//
// Key build settings:
//   - BUILD_LIBRARY_FOR_DISTRIBUTION = YES  →  generates .swiftinterface files
//   - SKIP_INSTALL = NO                     →  archives include the framework in Products/
//   - -package-name opentelemetry-swift-core →  lets `package` access modifier compile correctly;
//                                              `package` members are excluded from .swiftinterface
//   - GENERATE_INFOPLIST_FILE = YES         →  Tuist/Xcode auto-generates Info.plist for us

import ProjectDescription

// ---------------------------------------------------------------------------
// MARK: - Shared Build Settings
// ---------------------------------------------------------------------------

/// Common settings applied to every OTel framework target.
///
/// These are required for producing xcframeworks with stable ABI.
let sharedSettings: SettingsDictionary = [
    // Produce .swiftinterface files so consumers don't need to match compiler version.
    "BUILD_LIBRARY_FOR_DISTRIBUTION": "YES",

    // Ensure the framework is included in xcodebuild archive output.
    "SKIP_INSTALL": "NO",

    // Tell the compiler these sources belong to the `opentelemetry-swift-core` package.
    // This makes `package` access modifier declarations compile correctly.
    // The `package` members are automatically excluded from .swiftinterface files.
    "OTHER_SWIFT_FLAGS": "-package-name opentelemetry-swift-core",

    // Minimum deployment targets matching the upstream Package.swift.
    "IPHONEOS_DEPLOYMENT_TARGET": "13.0",
    "TVOS_DEPLOYMENT_TARGET": "13.0",
    "XROS_DEPLOYMENT_TARGET": "1.0",
    "MACOSX_DEPLOYMENT_TARGET": "10.15",

    // Support Mac Catalyst
    "SUPPORTS_MACCATALYST": "YES",

    // Enable module stability for library evolution.
    "SWIFT_EMIT_MODULE_INTERFACE": "YES"
]


// ---------------------------------------------------------------------------
// MARK: - Project
// ---------------------------------------------------------------------------

let project = Project(
    name: "OpenTelemetryXCFrameworks",
    settings: .settings(
        base: sharedSettings,
        configurations: [
            .debug(name: "Debug", settings: [:]),
            .release(name: "Release", settings: [:])
        ]
    ),
    targets: [

        // -----------------------------------------------------------------
        // MARK: OpenTelemetryApi
        // -----------------------------------------------------------------
        // The core API module. Contains trace, metrics, logs, baggage, and
        // context APIs. Has no external dependencies.
        //
        // Notable: contains 2 `package` declarations in Context/ that are
        // used only within this module (not cross-module). The -package-name
        // flag handles these; they are excluded from .swiftinterface.
        .target(
            name: "OpenTelemetryApi",
            destinations: [.iPhone, .iPad, .appleTv, .appleVision, .macCatalyst],
            product: .framework,
            bundleId: "io.opentelemetry.swift.api",
            sources: "vendor/opentelemetry-swift-core/Sources/OpenTelemetryApi/**",
            settings: .settings(
                base: [
                    "PRODUCT_MODULE_NAME": "OpenTelemetryApi",
                    "INFOPLIST_KEY_CFBundleDisplayName": "OpenTelemetryApi"
                ]
            )
        ),

        // -----------------------------------------------------------------
        // MARK: OpenTelemetrySdk
        // -----------------------------------------------------------------
        // The SDK module. Implements the API with concrete trace, metrics,
        // logs, and resource providers. Depends on OpenTelemetryApi.
        //
        // Notable: has ZERO `package` declarations. All access to
        // OpenTelemetryApi is through public API only. The -package-name
        // flag is still set (inherited from shared settings) for consistency.
        //
        // The upstream Atomics dependency is Linux-only (conditional in
        // Package.swift) so it is not included here.
        .target(
            name: "OpenTelemetrySdk",
            destinations: [.iPhone, .iPad, .appleTv, .appleVision, .macCatalyst],
            product: .framework,
            bundleId: "io.opentelemetry.swift.sdk",
            sources: "vendor/opentelemetry-swift-core/Sources/OpenTelemetrySdk/**",
            dependencies: [
                .target(name: "OpenTelemetryApi")
            ],
            settings: .settings(
                base: [
                    "PRODUCT_MODULE_NAME": "OpenTelemetrySdk",
                    "INFOPLIST_KEY_CFBundleDisplayName": "OpenTelemetrySdk"
                ]
            )
        )
    ]
)
