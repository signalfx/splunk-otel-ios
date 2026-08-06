// tools/xcframework/Project.swift
//
// Tuist manifest for building all SplunkAgent SDK modules as dynamic
// xcframeworks. Each module is a separate framework target with
// BUILD_LIBRARY_FOR_DISTRIBUTION=YES for stable ABI.
//
// External dependencies (OpenTelemetry and Cisco Session Replay) are
// consumed as pre-built xcframeworks from the `dependencies/` directory,
// populated by the build script before `tuist generate`.
//
// Key design decisions:
//   - Individual xcframework per module (not a single fat framework)
//   - Per-module platform matrix (SplunkCrashReports excludes visionOS)
//   - SplunkAgent's dependency on SplunkCrashReports uses a platform
//     condition so #if canImport(SplunkCrashReports) works correctly
//   - Cisco wrappers from Package.swift are NOT needed here — we
//     reference xcframeworks directly
//   - No linter/formatter plugins (those are dev-only in Package.swift)

import ProjectDescription

// ---------------------------------------------------------------------------
// MARK: - Path Constants
// ---------------------------------------------------------------------------

/// Path to the repository root, relative to this Project.swift.
let repoRoot: String = "../.."

/// Directory containing pre-built xcframeworks (OTel and Cisco).
///
/// Populated by the build script before `tuist generate`.
let deps: String = "dependencies"


// ---------------------------------------------------------------------------
// MARK: - Platform Definitions
// ---------------------------------------------------------------------------

/// All supported platforms for the majority of modules.
let allPlatforms: Set<Destination> = [
    .iPhone, .iPad, // iOS
    .appleTv, // tvOS
    .appleVision, // visionOS
    .macCatalyst // Mac Catalyst
]

/// Platforms excluding visionOS.
///
/// Used by SplunkCrashReporter and SplunkCrashReports (the crash reporter does not support visionOS).
let platformsNoCrashReporter: Set<Destination> = [
    .iPhone, .iPad, // iOS
    .appleTv, // tvOS
    .macCatalyst // Mac Catalyst
]

/// Platform condition: iOS + tvOS + Mac Catalyst (excludes visionOS).
///
/// Applied to SplunkCrashReports dependencies.
let noCrashReporterCondition = PlatformCondition.when([.ios, .tvos, .catalyst])


// ---------------------------------------------------------------------------
// MARK: - Shared Build Settings
// ---------------------------------------------------------------------------

/// Common build settings for all framework targets.
let sharedSettings: SettingsDictionary = [
    // Generate .swiftinterface files for module stability.
    "BUILD_LIBRARY_FOR_DISTRIBUTION": "YES",

    // Include the framework in xcodebuild archive output.
    "SKIP_INSTALL": "NO",

    // Enable module interface generation.
    "SWIFT_EMIT_MODULE_INTERFACE": "YES",

    // Tell the compiler these sources belong to the `SplunkAgent` package.
    // This makes `package` access compile in the standalone Tuist build while
    // keeping package-only members out of generated .swiftinterface files.
    "OTHER_SWIFT_FLAGS": "-package-name SplunkAgent",

    // Minimum deployment targets matching Package.swift.
    "IPHONEOS_DEPLOYMENT_TARGET": "13.0",
    "TVOS_DEPLOYMENT_TARGET": "15.0",
    "XROS_DEPLOYMENT_TARGET": "1.0",
    "MACOSX_DEPLOYMENT_TARGET": "12.0",

    // Support Mac Catalyst builds.
    "SUPPORTS_MACCATALYST": "YES"
]

/// Build settings for the vendored, namespaced crash reporter implementation.
let crashReporterSettings: SettingsDictionary = [
    "MACH_O_TYPE": "mh_dylib",
    "SKIP_INSTALL": "NO",
    "DEFINES_MODULE": "YES",
    "GCC_PREPROCESSOR_DEFINITIONS": [
        "PLCR_PRIVATE=1",
        "PLCF_RELEASE_BUILD=1",
        "PLCRASHREPORTER_PREFIX=SPLK",
        "SWIFT_PACKAGE=1"
    ],
    "HEADER_SEARCH_PATHS": [
        "$(SRCROOT)/\(repoRoot)/SplunkCrashReporter/Dependencies/protobuf-c",
        "$(SRCROOT)/\(repoRoot)/SplunkCrashReporter/Source"
    ],
    "OTHER_LDFLAGS": ["-framework", "Foundation"],
    "CLANG_ENABLE_MODULES": "YES",
    "CLANG_CXX_LANGUAGE_STANDARD": "c++17",
    "PUBLIC_HEADERS_FOLDER_PATH": "$(CONTENTS_FOLDER_PATH)/Headers"
]

/// Public headers exposed by the namespaced crash reporter framework.
let crashReporterPublicHeaders: FileList = [
    "\(repoRoot)/SplunkCrashReporter/include/*.h"
]


// ---------------------------------------------------------------------------
// MARK: - External Dependency Helpers
// ---------------------------------------------------------------------------
// These functions create xcframework dependency references to the pre-built
// dependencies directory. Using functions keeps the target definitions clean.

/// Reference to a pre-built xcframework in the dependencies directory.
func dep(_ name: String, condition: PlatformCondition? = nil) -> TargetDependency {
    .xcframework(path: "\(deps)/\(name).xcframework", condition: condition)
}

/// Reference to another target in this project (Splunk module).
func mod(_ name: String, condition: PlatformCondition? = nil) -> TargetDependency {
    .target(name: name, condition: condition)
}

/// CiscoDiskStorage's swiftinterface imports CiscoEncryption.
func ciscoDiskStorageDependencies() -> [TargetDependency] {
    [
        dep("CiscoDiskStorage"),
        dep("CiscoEncryption")
    ]
}

/// CiscoSwizzling's swiftinterface imports CiscoCommon.
func ciscoSwizzlingDependencies() -> [TargetDependency] {
    [
        dep("CiscoSwizzling"),
        dep("CiscoCommon")
    ]
}

/// CiscoInteractions' swiftinterface imports CiscoSwizzling.
func ciscoInteractionsDependencies() -> [TargetDependency] {
    [
        dep("CiscoInteractions"),
        dep("CiscoSwizzling"),
        dep("CiscoCommon")
    ]
}

/// CiscoRuntimeCache's swiftinterface imports CiscoLogger.
func ciscoRuntimeCacheDependencies() -> [TargetDependency] {
    [
        dep("CiscoRuntimeCache"),
        dep("CiscoLogger")
    ]
}

/// CiscoSessionReplay imports most Cisco support frameworks in its public interface.
func ciscoSessionReplayDependencies() -> [TargetDependency] {
    [
        dep("CiscoSessionReplay"),
        dep("CiscoCommon"),
        dep("CiscoDiskStorage"),
        dep("CiscoEncryption"),
        dep("CiscoInteractions"),
        dep("CiscoLogger"),
        dep("CiscoSwizzling"),
        dep("CiscoInstanceManager"),
        dep("CiscoRuntimeCache")
    ]
}

/// Vendored and symbol-prefixed PLCrashReporter implementation.
///
/// Kept as a typed declaration so the compiler does not have to infer this
/// mixed-source target as part of the complete project target array.
let crashReporterTarget = Target.target(
    name: "SplunkCrashReporter",
    destinations: platformsNoCrashReporter,
    product: .framework,
    bundleId: "com.splunk.rum.crashreporter",
    sources: [
        .glob("\(repoRoot)/SplunkCrashReporter/Source/**/*.c"),
        .glob("\(repoRoot)/SplunkCrashReporter/Source/**/*.m"),
        .glob("\(repoRoot)/SplunkCrashReporter/Source/**/*.mm"),
        .glob("\(repoRoot)/SplunkCrashReporter/Source/**/*.cpp"),
        .glob("\(repoRoot)/SplunkCrashReporter/Source/**/*.S"),
        .glob("\(repoRoot)/SplunkCrashReporter/Dependencies/protobuf-c/**/*.c")
    ],
    resources: [
        .glob(pattern: "\(repoRoot)/SplunkCrashReporter/Resources/PrivacyInfo.xcprivacy")
    ],
    headers: .headers(
        public: crashReporterPublicHeaders,
        private: [
            "\(repoRoot)/SplunkCrashReporter/Source/**/*.h",
            "\(repoRoot)/SplunkCrashReporter/Dependencies/protobuf-c/**/*.h"
        ],
        project: []
    ),
    settings: .settings(
        base: crashReporterSettings.merging([
            "PRODUCT_MODULE_NAME": "SplunkCrashReporter",
            "INFOPLIST_KEY_CFBundleDisplayName": "SplunkCrashReporter",
            "PRODUCT_NAME": "SplunkCrashReporter"
        ]) { _, new in new },
        configurations: [
            .debug(name: "Debug", settings: [:]),
            .release(
                name: "Release",
                settings: [
                    "GCC_PREPROCESSOR_DEFINITIONS": [
                        "PLCR_PRIVATE=1",
                        "PLCF_RELEASE_BUILD=1",
                        "NDEBUG=1",
                        "PLCRASHREPORTER_PREFIX=SPLK",
                        "SWIFT_PACKAGE=1"
                    ]
                ]
            )
        ]
    )
)


// ---------------------------------------------------------------------------
// MARK: - Project Definition
// ---------------------------------------------------------------------------

let project = Project(
    name: "SplunkAgentXCFrameworks",
    settings: .settings(
        base: sharedSettings,
        configurations: [
            .debug(name: "Debug", settings: [:]),
            .release(name: "Release", settings: [:])
        ]
    ),
    targets: [

        // =================================================================
        // MARK: SplunkCommon
        // =================================================================
        // Shared utilities, protocols, and types used by all other modules.
        // Depends on Cisco logger, disk storage, encryption, and OTel API.
        .target(
            name: "SplunkCommon",
            destinations: allPlatforms,
            product: .framework,
            bundleId: "com.splunk.rum.common",
            sources: "\(repoRoot)/SplunkCommon/Sources/**",
            dependencies: [
                dep("OpenTelemetryApi"),
                dep("CiscoLogger")
            ] + ciscoDiskStorageDependencies()
        ),


        // =================================================================
        // MARK: SplunkNavigation
        // =================================================================
        // Screen navigation tracking. Uses swizzling for automatic detection.
        .target(
            name: "SplunkNavigation",
            destinations: allPlatforms,
            product: .framework,
            bundleId: "com.splunk.rum.navigation",
            sources: "\(repoRoot)/SplunkNavigation/Sources/**",
            dependencies: [
                mod("SplunkCommon"),
                dep("OpenTelemetryApi"),
                dep("CiscoLogger")
            ] + ciscoSwizzlingDependencies()
        ),


        // =================================================================
        // MARK: SplunkNetwork
        // =================================================================
        // URLSession instrumentation for automatic HTTP span creation.
        .target(
            name: "SplunkNetwork",
            destinations: allPlatforms,
            product: .framework,
            bundleId: "com.splunk.rum.network",
            sources: "\(repoRoot)/SplunkNetwork/Sources/**",
            dependencies: [
                mod("SplunkCommon"),
                dep("OpenTelemetryApi"),
                dep("OpenTelemetrySdk"),
                dep("CiscoLogger")
            ]
        ),


        // =================================================================
        // MARK: SplunkNetworkMonitor
        // =================================================================
        // Network status monitoring (reachability, connection type).
        .target(
            name: "SplunkNetworkMonitor",
            destinations: allPlatforms,
            product: .framework,
            bundleId: "com.splunk.rum.networkmonitor",
            sources: "\(repoRoot)/SplunkNetworkMonitor/Sources/**",
            dependencies: [
                mod("SplunkCommon"),
                dep("OpenTelemetryApi"),
                dep("CiscoLogger")
            ]
        ),


        // =================================================================
        // MARK: SplunkSlowFrameDetector
        // =================================================================
        // Slow/frozen frame detection. Uses conditional compilation for
        // platform-specific display link APIs.
        .target(
            name: "SplunkSlowFrameDetector",
            destinations: allPlatforms,
            product: .framework,
            bundleId: "com.splunk.rum.slowframedetector",
            sources: "\(repoRoot)/SplunkSlowFrameDetector/Sources/**",
            dependencies: [
                mod("SplunkCommon"),
                dep("OpenTelemetryApi"),
                dep("CiscoLogger")
            ]
        ),


        // =================================================================
        // MARK: SplunkCrashReporter
        // =================================================================
        // Vendored and symbol-prefixed PLCrashReporter implementation.
        // The SPLK prefix prevents collisions with another copy linked by a host app.
        crashReporterTarget,


        // =================================================================
        // MARK: SplunkCrashReports
        // =================================================================
        // Crash reporting via PLCrashReporter.
        //
        // PLATFORM RESTRICTION: Excludes visionOS because PLCrashReporter
        // does not support it. This is the only module with a platform
        // restriction (besides the internal SplunkCrashReporter target).
        .target(
            name: "SplunkCrashReports",
            destinations: platformsNoCrashReporter,
            product: .framework,
            bundleId: "com.splunk.rum.crashreports",
            sources: "\(repoRoot)/SplunkCrashReports/Sources/**",
            dependencies: [
                mod("SplunkCommon"),
                dep("OpenTelemetryApi"),
                mod("SplunkCrashReporter")
            ]
        ),


        // =================================================================
        // MARK: SplunkOpenTelemetryBackgroundExporter
        // =================================================================
        // Custom OTLP/JSON exporters for traces, logs, and metrics with
        // background task support. Contains the custom OTLP encoder.
        .target(
            name: "SplunkOpenTelemetryBackgroundExporter",
            destinations: allPlatforms,
            product: .framework,
            bundleId: "com.splunk.rum.otelbackgroundexporter",
            sources: "\(repoRoot)/SplunkOpenTelemetryBackgroundExporter/Sources/**",
            dependencies: [
                mod("SplunkCommon"),
                dep("OpenTelemetryApi"),
                dep("OpenTelemetrySdk"),
                dep("CiscoLogger")
            ] + ciscoDiskStorageDependencies()
        ),


        // =================================================================
        // MARK: SplunkOpenTelemetry
        // =================================================================
        // OTel integration layer. Sets up span/log processors and
        // attribute handling using the background exporter.
        .target(
            name: "SplunkOpenTelemetry",
            destinations: allPlatforms,
            product: .framework,
            bundleId: "com.splunk.rum.opentelemetry",
            sources: "\(repoRoot)/SplunkOpenTelemetry/Sources/**",
            dependencies: [
                mod("SplunkOpenTelemetryBackgroundExporter"),
                dep("OpenTelemetryApi"),
                dep("OpenTelemetrySdk"),
                dep("CiscoLogger")
            ]
        ),


        // =================================================================
        // MARK: SplunkInteractions
        // =================================================================
        // UI interaction tracking (taps, gestures).
        // Uses swizzling and Cisco interactions library.
        .target(
            name: "SplunkInteractions",
            destinations: allPlatforms,
            product: .framework,
            bundleId: "com.splunk.rum.interactions",
            sources: "\(repoRoot)/SplunkInteractions/Sources/**",
            dependencies: [
                mod("SplunkCommon"),
                dep("OpenTelemetryApi")
            ] + ciscoRuntimeCacheDependencies()
                + ciscoInteractionsDependencies()
        ),


        // =================================================================
        // MARK: SplunkAppStart
        // =================================================================
        // App startup time tracking.
        .target(
            name: "SplunkAppStart",
            destinations: allPlatforms,
            product: .framework,
            bundleId: "com.splunk.rum.appstart",
            sources: "\(repoRoot)/SplunkAppStart/Sources/**",
            dependencies: [
                mod("SplunkCommon"),
                dep("OpenTelemetryApi"),
                dep("CiscoLogger")
            ]
        ),


        // =================================================================
        // MARK: SplunkAppState
        // =================================================================
        // App lifecycle events (foreground/background transitions).
        .target(
            name: "SplunkAppState",
            destinations: allPlatforms,
            product: .framework,
            bundleId: "com.splunk.rum.appstate",
            sources: "\(repoRoot)/SplunkAppState/Sources/**",
            dependencies: [
                mod("SplunkCommon"),
                dep("OpenTelemetryApi"),
                dep("CiscoLogger")
            ]
        ),


        // =================================================================
        // MARK: SplunkWebView
        // =================================================================
        // WKWebView instrumentation bridge. Uses conditional compilation
        // for WebKit availability.
        .target(
            name: "SplunkWebView",
            destinations: allPlatforms,
            product: .framework,
            bundleId: "com.splunk.rum.webview",
            sources: "\(repoRoot)/SplunkWebView/Sources/**",
            resources: [
                .glob(pattern: "\(repoRoot)/SplunkWebView/Resources/**")
            ],
            dependencies: [
                mod("SplunkCommon"),
                dep("CiscoLogger")
            ]
        ),


        // =================================================================
        // MARK: SplunkCustomTracking
        // =================================================================
        // Custom events and workflow tracking.
        .target(
            name: "SplunkCustomTracking",
            destinations: allPlatforms,
            product: .framework,
            bundleId: "com.splunk.rum.customtracking",
            sources: "\(repoRoot)/SplunkCustomTracking/Sources/**",
            dependencies: [
                mod("SplunkCommon"),
                mod("SplunkOpenTelemetry"),
                dep("CiscoLogger")
            ]
        ),


        // =================================================================
        // MARK: SplunkSessionReplayProxy
        // =================================================================
        // Session replay proxy. Bridges the Cisco SessionReplay module
        // to the Splunk Module protocol.
        .target(
            name: "SplunkSessionReplayProxy",
            destinations: allPlatforms,
            product: .framework,
            bundleId: "com.splunk.rum.sessionreplayproxy",
            sources: "\(repoRoot)/SplunkSessionReplayProxy/Sources/**",
            dependencies: [
                mod("SplunkCommon")
            ] + ciscoSessionReplayDependencies()
        ),


        // =================================================================
        // MARK: SplunkAgent
        // =================================================================
        // Main agent framework and public API. Orchestrates all modules.
        //
        // CONDITIONAL DEPENDENCY: SplunkCrashReports is only included on
        // iOS, tvOS, and Mac Catalyst (not visionOS). The source code uses
        // `#if canImport(SplunkCrashReports)` guards throughout, so when
        // building for visionOS the crash reporting code is excluded.
        .target(
            name: "SplunkAgent",
            destinations: allPlatforms,
            product: .framework,
            bundleId: "com.splunk.rum.agent",
            sources: "\(repoRoot)/SplunkAgent/Sources/SplunkAgent/**",
            resources: [
                .glob(pattern: "\(repoRoot)/SplunkAgent/Resources/PrivacyInfo.xcprivacy"),
                .glob(pattern: "\(repoRoot)/SplunkAgent/Resources/NOTICES")
            ],
            dependencies: [
                mod("SplunkCommon"),
                mod("SplunkSessionReplayProxy"),
                mod("SplunkNavigation"),
                mod("SplunkNetwork"),
                mod("SplunkNetworkMonitor"),
                mod("SplunkSlowFrameDetector"),
                mod("SplunkOpenTelemetry"),
                mod("SplunkInteractions"),
                mod("SplunkAppStart"),
                mod("SplunkAppState"),
                mod("SplunkWebView"),
                mod("SplunkCustomTracking"),
                dep("OpenTelemetryApi"),
                dep("OpenTelemetrySdk"),
                dep("CiscoLogger"),

                // Conditional: only on platforms where PLCrashReporter is available
                mod("SplunkCrashReports", condition: noCrashReporterCondition)
            ]
        ),


        // =================================================================
        // MARK: SplunkAgentObjC
        // =================================================================
        // Objective-C bridging layer for SplunkAgent.
        .target(
            name: "SplunkAgentObjC",
            destinations: allPlatforms,
            product: .framework,
            bundleId: "com.splunk.rum.agentobjc",
            sources: "\(repoRoot)/SplunkAgent/Sources/SplunkAgentObjC/**",
            resources: [
                .glob(pattern: "\(repoRoot)/SplunkAgent/Resources/PrivacyInfo.xcprivacy"),
                .glob(pattern: "\(repoRoot)/SplunkAgent/Resources/NOTICES")
            ],
            dependencies: [
                mod("SplunkAgent"),
                mod("SplunkCommon"),
                mod("SplunkCustomTracking"),
                mod("SplunkInteractions"),
                mod("SplunkNavigation"),
                mod("SplunkNetworkMonitor"),
                mod("SplunkSlowFrameDetector"),

                // Conditional: needed for CrashReportsConfigurationObjC+Conversions.swift
                // which uses #if canImport(SplunkCrashReports) to bridge config types.
                mod("SplunkCrashReports", condition: noCrashReporterCondition)
            ]
        )
    ]
)
