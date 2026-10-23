// swift-tools-version: 5.9

// swiftformat:disable sortImports
import PackageDescription

import class Foundation.ProcessInfo

// MARK: - Package and target definitions

/// Create the package instance base.
let package = Package(
    name: "SplunkAgent",
    platforms: [
        .iOS(.v15),
        .tvOS(.v15),
        .visionOS(.v1),
        .macCatalyst(.v15)
    ],
    products: [
        .library(
            name: "SplunkAgent",
            targets: ["SplunkAgent"]
        ),
        .library(
            name: "SplunkAgentObjC",
            targets: ["SplunkAgentObjC"]
        )
    ],
    dependencies: [
        // Note: opentelemetry-swift package (with OpenTelemetryProtocolExporter) was removed
        // in favor of custom OTLP JSON encoding. We now only use opentelemetry-swift-core.
        //
        // IMPORTANT: These versions are pinned with `exact:` because the xcframework build
        // system (tools/xcframework/Makefile) reads them to build matching binaries.
        // When upgrading, update the version here — the Makefile picks it up automatically.
        .package(
            url: "https://github.com/open-telemetry/opentelemetry-swift-core",
            exact: "2.3.0"
        )
    ],
    targets: []
)

// Modify it based on current dependency resolution and add all targets to the package

package.targets.append(contentsOf: generateBinaryTargets())
package.targets.append(contentsOf: generateWrapperTargets())
package.targets.append(contentsOf: generateMainTargets())

// Conditionally add all required plugin dependencies

package.dependencies.append(contentsOf: pluginDependencies())

// Conditionally add Session Replay as a repository dependency
resolveSessionReplayRepositoryDependency()


// MARK: - Helpers for target generation

/// Generates the main library targets.
func generateMainTargets() -> [Target] {
    [

        // MARK: - Splunk Agent

        .target(
            name: "SplunkAgent",
            dependencies: [
                "SplunkCommon",
                .target(
                    name: "SplunkCrashReports",
                    condition: .when(platforms: [.iOS, .tvOS, .macCatalyst])
                ),
                "SplunkSessionReplayProxy",
                "SplunkNavigation",
                "SplunkNetwork",
                "SplunkNetworkMonitor",
                "SplunkSlowFrameDetector",
                "SplunkAppHangMonitor",
                "SplunkOpenTelemetry",
                "SplunkInteractions",
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift-core"),
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift-core"),
                "SplunkAppStart",
                "SplunkAppState",
                "SplunkWebView",
                "SplunkCustomTracking",
                resolveDependency("logger")
            ],
            path: "SplunkAgent/Sources/SplunkAgent",
            resources: [
                .copy("../../Resources/PrivacyInfo.xcprivacy"),
                .copy("../../Resources/NOTICES")
            ],
            plugins: lintMainTargetPlugins()
        ),
        .testTarget(
            name: "SplunkAgentTests",
            dependencies: ["SplunkAgent", "SplunkCommon", "SplunkAppState", "SplunkCustomTracking"],
            path: "SplunkAgent/Tests/SplunkAgentTests",
            resources: [
                .copy("Testing Support/Assets/v.mp4"),
                .copy("Testing Support/Mock Data/AlternativeRemoteConfiguration.json"),
                .copy("Testing Support/Mock Data/RemoteConfiguration.json"),
                .copy("Testing Support/Mock Data/RemoteError.json")
            ],
            swiftSettings: [
                .define("SPM_TESTS")
            ],
            plugins: lintMainTargetPlugins()
        ),


        // MARK: - Splunk Agent (Objective-C bridge)

        .target(
            name: "SplunkAgentObjC",
            dependencies: [
                "SplunkAgent",
                "SplunkCommon",
                "SplunkCustomTracking",
                "SplunkInteractions",
                "SplunkNavigation",
                "SplunkNetworkMonitor",
                "SplunkSlowFrameDetector",
                "SplunkAppHangMonitor",
                .target(
                    name: "SplunkCrashReports",
                    condition: .when(platforms: [.iOS, .tvOS, .macCatalyst])
                )
            ],
            path: "SplunkAgent/Sources/SplunkAgentObjC",
            resources: [
                .copy("../../Resources/PrivacyInfo.xcprivacy"),
                .copy("../../Resources/NOTICES")
            ],
            plugins: lintMainTargetPlugins()
        ),
        .testTarget(
            name: "SplunkAgentObjCTests",
            dependencies: ["SplunkAgentObjC"],
            path: "SplunkAgent/Tests/SplunkAgentObjCTests"
        ),
        // Swift tests for the ObjC-to-internal bridging layer (adapters,
        // config conversions). Separate from SplunkAgentObjCTests because
        // SPM does not support mixed-language targets. That target contains
        // Objective-C (.m) files for ObjC-callability tests.
        .testTarget(
            name: "SplunkAgentBridgingTests",
            dependencies: ["SplunkAgentObjC", "SplunkCustomTracking", "SplunkNavigation"],
            path: "SplunkAgent/Tests/SplunkAgentBridgingTests"
        ),


        // MARK: - Splunk Navigation (Instrumentation)

        .target(
            name: "SplunkNavigation",
            dependencies: [
                "SplunkCommon",
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift-core"),
                resolveDependency("logger"),
                resolveDependency("swizzling")
            ],
            path: "SplunkNavigation/Sources",
            plugins: lintTargetPlugins()
        ),
        .testTarget(
            name: "SplunkNavigationTests",
            dependencies: [
                "SplunkCommon",
                "SplunkNavigation",
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift-core"),
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift-core")
            ],
            path: "SplunkNavigation/Tests",
            plugins: lintTargetPlugins()
        ),


        // MARK: - Splunk Network (Instrumentation)

        .target(
            name: "SplunkNetwork",
            dependencies: [
                "SplunkCommon",
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift-core"),
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift-core"),
                resolveDependency("logger")
            ],
            path: "SplunkNetwork/Sources",
            plugins: lintTargetPlugins()
        ),
        .testTarget(
            name: "SplunkNetworkTests",
            dependencies: [
                "SplunkNetwork",
                "SplunkOpenTelemetry"
            ],
            path: "SplunkNetwork/Tests",
            plugins: lintTargetPlugins()
        ),


        // MARK: - Splunk Network Monitor

        .target(
            name: "SplunkNetworkMonitor",
            dependencies: [
                "SplunkCommon",
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift-core"),
                resolveDependency("logger")
            ],
            path: "SplunkNetworkMonitor/Sources",
            plugins: lintTargetPlugins()
        ),
        .testTarget(
            name: "SplunkNetworkMonitorTests",
            dependencies: [
                "SplunkNetworkMonitor"
            ],
            path: "SplunkNetworkMonitor/Tests",
            plugins: lintTargetPlugins()
        ),


        // MARK: - Splunk Common

        .target(
            name: "SplunkCommon",
            dependencies: [
                resolveDependency("diskStorage"),
                resolveDependency("encryptor"),
                resolveDependency("logger"),
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift-core")
            ],
            path: "SplunkCommon/Sources",
            plugins: lintTargetPlugins()
        ),
        .testTarget(
            name: "SplunkCommonTests",
            dependencies: [
                "SplunkCommon"
            ],
            path: "SplunkCommon/Tests",
            plugins: lintTargetPlugins()
        ),


        // MARK: - Splunk Slow Frame Detector (Instrumentation)

        .target(
            name: "SplunkSlowFrameDetector",
            dependencies: [
                .byName(name: "SplunkCommon"),
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift-core"),
                resolveDependency("logger")
            ],
            path: "SplunkSlowFrameDetector/Sources",
            plugins: lintTargetPlugins()
        ),
        .testTarget(
            name: "SplunkSlowFrameDetectorTests",
            dependencies: [
                "SplunkSlowFrameDetector",
                "SplunkCommon"
            ],
            path: "SplunkSlowFrameDetector/Tests",
            plugins: lintTargetPlugins()
        ),


        // MARK: - Splunk App Hang Monitor (Instrumentation)

        .target(
            name: "SplunkAppHangMonitor",
            dependencies: [
                "SplunkCommon",
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift-core")
            ],
            path: "SplunkAppHangMonitor/Sources",
            plugins: lintTargetPlugins()
        ),


        // MARK: - SplunkCrashReporter

        .target(
            name: "SplunkCrashReporter",
            path: "SplunkCrashReporter",
            exclude: [
                "Source/dwarf_opstream.hpp",
                "Source/dwarf_stack.hpp",
                "Source/PLCrashAsyncDwarfCFAState.hpp",
                "Source/PLCrashAsyncDwarfCIE.hpp",
                "Source/PLCrashAsyncDwarfEncoding.hpp",
                "Source/PLCrashAsyncDwarfExpression.hpp",
                "Source/PLCrashAsyncDwarfFDE.hpp",
                "Source/PLCrashAsyncDwarfPrimitives.hpp",
                "Source/PLCrashAsyncLinkedList.hpp",
                "Source/PLCrashReport.proto"
            ],
            sources: [
                "Source",
                "Dependencies/protobuf-c"
            ],
            resources: [
                .process("Resources/PrivacyInfo.xcprivacy")
            ],
            cSettings: [
                .define("PLCR_PRIVATE"),
                .define("PLCF_RELEASE_BUILD"),
                .define("NDEBUG", .when(configuration: .release)),
                .define("PLCRASHREPORTER_PREFIX", to: "SPLK"),
                .define("SWIFT_PACKAGE"), // Should be defined by default, Xcode 11.1 workaround.
                .headerSearchPath("Dependencies/protobuf-c"),
                .headerSearchPath("Source")
            ],
            linkerSettings: [
                .linkedFramework("Foundation")
            ]
        ),


        // MARK: - SplunkCrashReports (Instrumentation)

        .target(
            name: "SplunkCrashReports",
            dependencies: [
                "SplunkCommon",
                .target(
                    name: "SplunkCrashReporter",
                    condition: .when(platforms: [.iOS, .tvOS, .macCatalyst])
                ),
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift-core")
            ],
            path: "SplunkCrashReports/Sources",
            plugins: lintTargetPlugins()
        ),
        .testTarget(
            name: "SplunkCrashReportsTests",
            dependencies: [
                "SplunkCrashReports",
                "SplunkCommon",
                "SplunkCrashReporter"
            ],
            path: "SplunkCrashReports/Tests",
            plugins: lintTargetPlugins()
        ),


        // MARK: - Splunk OTel

        .target(
            name: "SplunkOpenTelemetry",
            dependencies: [
                "SplunkOpenTelemetryBackgroundExporter",
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift-core"),
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift-core"),
                resolveDependency("logger")
            ],
            path: "SplunkOpenTelemetry/Sources",
            plugins: lintTargetPlugins()
        ),
        .testTarget(
            name: "SplunkOpenTelemetryTests",
            dependencies: [
                "SplunkOpenTelemetry",
                "SplunkCommon",
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift-core"),
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift-core")
            ],
            path: "SplunkOpenTelemetry/Tests",
            plugins: lintTargetPlugins()
        ),


        // MARK: - Splunk OTel Background Exporter

        .target(
            name: "SplunkOpenTelemetryBackgroundExporter",
            dependencies: [
                "SplunkCommon",
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift-core"),
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift-core"),
                resolveDependency("logger"),
                resolveDependency("diskStorage")
            ],
            path: "SplunkOpenTelemetryBackgroundExporter/Sources",
            plugins: lintTargetPlugins()
        ),
        .testTarget(
            name: "SplunkOpenTelemetryBackgroundExporterTests",
            dependencies: [
                "SplunkOpenTelemetryBackgroundExporter",
                "SplunkCommon"
            ],
            path: "SplunkOpenTelemetryBackgroundExporter/Tests",
            plugins: lintTargetPlugins()
        ),


        // MARK: - Splunk Interactions

        .target(
            name: "SplunkInteractions",
            dependencies: [
                "SplunkCommon",
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift-core"),
                resolveDependency("runtimeCache"),
                resolveDependency("logger"),
                resolveDependency("swizzling"),
                resolveDependency("interactions")
            ],
            path: "SplunkInteractions/Sources",
            plugins: lintTargetPlugins()
        ),
        .testTarget(
            name: "SplunkInteractionsTests",
            dependencies: [
                "SplunkInteractions"
            ],
            path: "SplunkInteractions/Tests",
            plugins: lintTargetPlugins()
        ),


        // MARK: - Splunk App Start (Instrumentation)

        .target(
            name: "SplunkAppStart",
            dependencies: [
                "SplunkCommon",
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift-core"),
                resolveDependency("logger")
            ],
            path: "SplunkAppStart/Sources",
            plugins: lintTargetPlugins()
        ),
        .testTarget(
            name: "SplunkAppStartTests",
            dependencies: [
                "SplunkAppStart"
            ],
            path: "SplunkAppStart/Tests",
            plugins: lintTargetPlugins()
        ),


        // MARK: - Splunk App State

        .target(
            name: "SplunkAppState",
            dependencies: [
                "SplunkCommon",
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift-core"),
                resolveDependency("logger")
            ],
            path: "SplunkAppState/Sources",
            plugins: lintTargetPlugins()
        ),
        .testTarget(
            name: "SplunkAppStateTests",
            dependencies: [
                "SplunkAppState"
            ],
            path: "SplunkAppState/Tests",
            plugins: lintTargetPlugins()
        ),


        // MARK: - Splunk Web (Instrumentation)

        .target(
            name: "SplunkWebView",
            dependencies: [
                "SplunkCommon",
                resolveDependency("logger")
            ],
            path: "SplunkWebView",
            sources: ["Sources"],
            resources: [
                .process("Resources")
            ],
            plugins: lintTargetPlugins()
        ),
        .testTarget(
            name: "SplunkWebViewTests",
            dependencies: [
                "SplunkWebView",
                resolveDependency("logger")
            ],
            path: "SplunkWebView/Tests",
            plugins: lintTargetPlugins()
        ),


        // MARK: - Splunk Custom Tracking

        .target(
            name: "SplunkCustomTracking",
            dependencies: [
                "SplunkCommon",
                "SplunkOpenTelemetry",
                resolveDependency("logger")
            ],
            path: "SplunkCustomTracking/Sources",
            plugins: lintTargetPlugins()
        ),
        .testTarget(
            name: "SplunkCustomTrackingTests",
            dependencies: [
                "SplunkCommon",
                "SplunkOpenTelemetry",
                "SplunkCustomTracking",
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift-core"),
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift-core")
            ],
            path: "SplunkCustomTracking/Tests",
            plugins: lintTargetPlugins()
        ),


        // MARK: - Session Replay Proxy

        .target(
            name: "SplunkSessionReplayProxy",
            dependencies: [
                "SplunkCommon",
                resolveDependency("sessionReplay")
            ],
            path: "SplunkSessionReplayProxy/Sources",
            plugins: lintTargetPlugins()
        )
    ]
}

/// Generates binary targets from the registry, based on the current `DependencyResolutionStrategy`.
func generateBinaryTargets() -> [Target] {

    // First check the dependency resolution whether we want to generate.
    guard DependencyResolutionStrategy.current == .binaryTargets else {
        return []
    }

    return SessionReplayBinaryRegistry.targets.values.map { info in
        .binaryTarget(
            name: info.name,
            url: info.url,
            checksum: info.checksum
        )
    }
}

/// Generates wrapper targets, based on the current `DependencyResolutionStrategy`.
func generateWrapperTargets() -> [Target] {

    // First check the dependency resolution whether we want to generate.
    guard DependencyResolutionStrategy.current == .binaryTargets else {
        return []
    }

    return generateBinaryWrapperTargets()
}

/// Generates wrapper targets that depend on binary targets to correctly construct and link their dependency trees.
func generateBinaryWrapperTargets() -> [Target] {
    [
        .target(
            name: "CiscoCommonWrapper",
            dependencies: ["CiscoCommon"],
            path: "TargetWrappers/CiscoCommonWrapper/Sources"
        ),
        .target(
            name: "CiscoLoggerWrapper",
            dependencies: ["CiscoLogger"],
            path: "TargetWrappers/CiscoLoggerWrapper/Sources"
        ),
        .target(
            name: "CiscoEncryptionWrapper",
            dependencies: ["CiscoEncryption"],
            path: "TargetWrappers/CiscoEncryptionWrapper/Sources"
        ),
        .target(
            name: "CiscoSwizzlingWrapper",
            dependencies: ["CiscoSwizzling", resolveDependency("common")],
            path: "TargetWrappers/CiscoSwizzlingWrapper/Sources"
        ),
        .target(
            name: "CiscoInteractionsWrapper",
            dependencies: ["CiscoInteractions", resolveDependency("swizzling")],
            path: "TargetWrappers/CiscoInteractionsWrapper/Sources"
        ),
        .target(
            name: "CiscoDiskStorageWrapper",
            dependencies: ["CiscoDiskStorage", resolveDependency("encryptor")],
            path: "TargetWrappers/CiscoDiskStorageWrapper/Sources"
        ),
        .target(
            name: "CiscoVideoEncoderWrapper",
            dependencies: [
                "CiscoVideoEncoder",
                resolveDependency("common"),
                resolveDependency("diskStorage"),
                resolveDependency("logger")
            ],
            path: "TargetWrappers/CiscoVideoEncoderWrapper/Sources"
        ),
        .target(
            name: "CiscoScreenshotWrapper",
            dependencies: [
                "CiscoScreenshot",
                resolveDependency("common"),
                resolveDependency("logger")
            ],
            path: "TargetWrappers/CiscoScreenshotWrapper/Sources"
        ),
        .target(
            name: "CiscoWireframeWrapper",
            dependencies: [
                "CiscoWireframe",
                resolveDependency("common"),
                resolveDependency("logger"),
                resolveDependency("runtimeCache"),
                resolveDependency("screenshot")
            ],
            path: "TargetWrappers/CiscoWireframeWrapper/Sources"
        ),
        .target(
            name: "CiscoDataExporterWrapper",
            dependencies: [
                "CiscoDataExporter",
                resolveDependency("common"),
                resolveDependency("interactions"),
                resolveDependency("wireframe")
            ],
            path: "TargetWrappers/CiscoDataExporterWrapper/Sources"
        ),
        .target(
            name: "CiscoSnapshotManagerWrapper",
            dependencies: [
                "CiscoSnapshotManager",
                resolveDependency("common"),
                resolveDependency("logger"),
                resolveDependency("screenshot"),
                resolveDependency("wireframe")
            ],
            path: "TargetWrappers/CiscoSnapshotManagerWrapper/Sources"
        ),
        .target(
            name: "CiscoInstanceManagerWrapper",
            dependencies: [
                "CiscoInstanceManager",
                resolveDependency("diskStorage"),
                resolveDependency("encryptor"),
                resolveDependency("logger")
            ],
            path: "TargetWrappers/CiscoInstanceManagerWrapper/Sources"
        ),
        .target(
            name: "CiscoRuntimeCacheWrapper",
            dependencies: [
                "CiscoRuntimeCache",
                resolveDependency("common"),
                resolveDependency("logger")
            ],
            path: "TargetWrappers/CiscoRuntimeCacheWrapper/Sources"
        ),
        .target(
            name: "CiscoSessionReplayWrapper",
            dependencies: [
                "CiscoSessionReplay",
                resolveDependency("common"),
                resolveDependency("dataExporter"),
                resolveDependency("diskStorage"),
                resolveDependency("encryptor"),
                resolveDependency("interactions"),
                resolveDependency("logger"),
                resolveDependency("runtimeCache"),
                resolveDependency("screenshot"),
                resolveDependency("snapshotManager"),
                resolveDependency("swizzling"),
                resolveDependency("videoEncoder"),
                resolveDependency("wireframe"),
                resolveDependency("instanceManager")
            ],
            path: "TargetWrappers/CiscoSessionReplayWrapper/Sources"
        )
    ]
}


// MARK: - Target plugins

/// Determines whether to use development plugins as a repository dependency.
///
/// This is the main switch for enabling linter and formaters plugins.
func shouldUseDevelopmentPlugins() -> Bool {
    // Check the ENV first
    if let envValue = ProcessInfo.processInfo.environment["USE_DEVELOPMENT_PLUGINS"],
        let boolValue = Bool(envValue)
    {
        return boolValue
    }

    // Default to *not use any plugins*
    return false
}

/// List of used plugin dependencies.
func pluginDependencies() -> [Package.Dependency] {
    guard shouldUseDevelopmentPlugins() else {
        return []
    }

    return [
        // SwiftLint (realm)
        .package(
            url: "https://github.com/SimplyDanny/SwiftLintPlugins",
            from: "0.62.2"
        ),

        // swift-format (swiftlang)
        .package(
            url: "https://github.com/StarLard/SwiftFormatPlugins",
            from: "1.1.0"
        ),

        // SwiftFormat (nicklockwood)
        .package(
            url: "https://github.com/nicklockwood/SwiftFormat",
            from: "0.57.2"
        )
    ]
}

/// List of used lint plugins in main targets.
func lintMainTargetPlugins() -> [Target.PluginUsage] {
    guard shouldUseDevelopmentPlugins() else {
        return []
    }

    return [
        .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins"),
        .plugin(name: "Lint", package: "SwiftFormatPlugins")
    ]
}

/// List of used lint plugins in every target.
func lintTargetPlugins() -> [Target.PluginUsage] {
    guard shouldUseDevelopmentPlugins() else {
        return []
    }

    return [
        .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins"),
        .plugin(name: "Lint", package: "SwiftFormatPlugins")
    ]
}


// MARK: - Binary target registry

/// Registry containing all Session Replay binary target definitions.
struct SessionReplayBinaryRegistry {

    /// Internal descriptor of the Target structure, including its Wrapper name for generation.
    struct BinaryTargetInfo {
        let name: String
        let url: String
        let checksum: String
        let productName: String
        let wrapperName: String
    }

    static let targets: [String: BinaryTargetInfo] = [
        "common": BinaryTargetInfo(
            name: "CiscoCommon",
            url: "https://sdk.smartlook.com/cisco-session-replay/ios/2.0.0/staticlib/cisco-common-2.0.0.300.zip",
            checksum: "b3dd6ec86f238be65ea821778fb570d0db989fe6575e6626f4e02ea93e12936a",
            productName: "CiscoCommon",
            wrapperName: "CiscoCommonWrapper"
        ),
        "logger": BinaryTargetInfo(
            name: "CiscoLogger",
            url: "https://sdk.smartlook.com/cisco-session-replay/ios/2.0.0/staticlib/cisco-logger-2.0.0.300.zip",
            checksum: "b2126083d296ede79821fb425e05526e49e0e35836d7a445974c56306d7eb967",
            productName: "CiscoLogger",
            wrapperName: "CiscoLoggerWrapper"
        ),
        "encryptor": BinaryTargetInfo(
            name: "CiscoEncryption",
            url: "https://sdk.smartlook.com/cisco-session-replay/ios/2.0.0/staticlib/cisco-encryption-2.0.0.300.zip",
            checksum: "43a0f3fe875fe9255747251998b3ffb9b1d06a224c2ef6936407ce5c2dc5668b",
            productName: "CiscoEncryption",
            wrapperName: "CiscoEncryptionWrapper"
        ),
        "swizzling": BinaryTargetInfo(
            name: "CiscoSwizzling",
            url: "https://sdk.smartlook.com/cisco-session-replay/ios/2.0.0/staticlib/cisco-swizzling-2.0.0.300.zip",
            checksum: "6e1853180a96b520cb1efd989424c438e19af8a47a04968afd3dc9cb38efc5ab",
            productName: "CiscoSwizzling",
            wrapperName: "CiscoSwizzlingWrapper"
        ),
        "interactions": BinaryTargetInfo(
            name: "CiscoInteractions",
            url: "https://sdk.smartlook.com/cisco-session-replay/ios/2.0.0/staticlib/cisco-interactions-2.0.0.300.zip",
            checksum: "0fafef828075477913382393315fea703f64655355c9e33892280876b64acfb1",
            productName: "CiscoInteractions",
            wrapperName: "CiscoInteractionsWrapper"
        ),
        "diskStorage": BinaryTargetInfo(
            name: "CiscoDiskStorage",
            url: "https://sdk.smartlook.com/cisco-session-replay/ios/2.0.0/staticlib/cisco-disk-storage-2.0.0.300.zip",
            checksum: "3a7def04b10cb19fbd3fe989d40057aba7544d8ff9da94f311fb91eeb091febf",
            productName: "CiscoDiskStorage",
            wrapperName: "CiscoDiskStorageWrapper"
        ),
        "videoEncoder": BinaryTargetInfo(
            name: "CiscoVideoEncoder",
            url: "https://sdk.smartlook.com/cisco-session-replay/ios/2.0.0/staticlib/cisco-video-encoder-2.0.0.300.zip",
            checksum: "87c658ebd0e096d8c3ab013b03bf98f6cb9d0658ff2376e658f80970e2620b1e",
            productName: "CiscoVideoEncoder",
            wrapperName: "CiscoVideoEncoderWrapper"
        ),
        "screenshot": BinaryTargetInfo(
            name: "CiscoScreenshot",
            url: "https://sdk.smartlook.com/cisco-session-replay/ios/2.0.0/staticlib/cisco-screenshot-2.0.0.300.zip",
            checksum: "43466fc79ee63421272086c0e11ce50d4269263b4108eccef8c352324aae4004",
            productName: "CiscoScreenshot",
            wrapperName: "CiscoScreenshotWrapper"
        ),
        "wireframe": BinaryTargetInfo(
            name: "CiscoWireframe",
            url: "https://sdk.smartlook.com/cisco-session-replay/ios/2.0.0/staticlib/cisco-wireframe-2.0.0.300.zip",
            checksum: "14ec9123d966df6b53853dfdd66278477b3a96de684e1813f9b0ebaf3735622b",
            productName: "CiscoWireframe",
            wrapperName: "CiscoWireframeWrapper"
        ),
        "dataExporter": BinaryTargetInfo(
            name: "CiscoDataExporter",
            url: "https://sdk.smartlook.com/cisco-session-replay/ios/2.0.0/staticlib/cisco-data-exporter-2.0.0.300.zip",
            checksum: "0bb937588979fa19b3f8393727a38d5254689e04aae1853a54eeb20259ba63bd",
            productName: "CiscoDataExporter",
            wrapperName: "CiscoDataExporterWrapper"
        ),
        "snapshotManager": BinaryTargetInfo(
            name: "CiscoSnapshotManager",
            url: "https://sdk.smartlook.com/cisco-session-replay/ios/2.0.0/staticlib/cisco-snapshot-manager-2.0.0.300.zip",
            checksum: "5111f46e85658a288be66c922ba432693408fe13d4fa8e727aa65e24b348eb66",
            productName: "CiscoSnapshotManager",
            wrapperName: "CiscoSnapshotManagerWrapper"
        ),
        "sessionReplay": BinaryTargetInfo(
            name: "CiscoSessionReplay",
            url: "https://sdk.smartlook.com/cisco-session-replay/ios/2.0.0/staticlib/cisco-session-replay-2.0.0.300.zip",
            checksum: "9b00da766e3d23e1c5cba089a4cad95ac8c50d504950c539ac161af7679d7f8d",
            productName: "CiscoSessionReplay",
            wrapperName: "CiscoSessionReplayWrapper"
        ),
        "instanceManager": BinaryTargetInfo(
            name: "CiscoInstanceManager",
            url: "https://sdk.smartlook.com/cisco-session-replay/ios/2.0.0/staticlib/cisco-instance-manager-2.0.0.300.zip",
            checksum: "1e1d3bfa36de117bc62b501820fd26db6dbe4c152d3c6863d967ded01bf0ed6a",
            productName: "CiscoInstanceManager",
            wrapperName: "CiscoInstanceManagerWrapper"
        ),
        "runtimeCache": BinaryTargetInfo(
            name: "CiscoRuntimeCache",
            url: "https://sdk.smartlook.com/cisco-session-replay/ios/2.0.0/staticlib/cisco-runtime-cache-2.0.0.300.zip",
            checksum: "dafaf00f423bb3aacfb5c1e56ce0bea388d65b7c12bd0b65d142c97b39b4ed01",
            productName: "CiscoRuntimeCache",
            wrapperName: "CiscoRuntimeCacheWrapper"
        )
    ]
}

/// Determines which dependency resolution strategy to use.
///
/// Defaults to `.binaryTargets`, present in the `current` property.
enum DependencyResolutionStrategy {

    /// SessionReplay dependencies are linked as binary targets
    /// fetched from S3 storage.
    case binaryTargets

    /// SessionReplay dependencies are linked as products
    /// from a SPM-linked SR repository.
    case repositoryDependency

    static var current: DependencyResolutionStrategy {
        guard shouldUseSessionReplayAsRepositoryDependency() else {
            return .binaryTargets
        }

        return .repositoryDependency
    }
}

/// Resolves a dependency based on the current strategy.
///
/// - Parameter key: The key from `SessionReplayBinaryRegistry.targets`.
/// - Returns: A dependency reference (either wrapper target name or product reference).
func resolveDependency(_ key: String) -> Target.Dependency {
    guard let targetInfo = SessionReplayBinaryRegistry.targets[key] else {
        fatalError("Unknown Session Replay dependency key: \(key)")
    }

    switch DependencyResolutionStrategy.current {
    case .binaryTargets:
        return .byName(name: targetInfo.wrapperName)

    case .repositoryDependency:
        return .product(name: targetInfo.productName, package: "smartlook-ios-sdk-private")
    }
}


// MARK: - Session Replay related helpers

/// Determines whether to use Session Replay as a repository dependency.
///
/// This is the main switch between binary targets and repository-based approach.
func shouldUseSessionReplayAsRepositoryDependency() -> Bool {

    // Check the ENV first
    if let envValue = ProcessInfo.processInfo.environment["USE_SESSION_REPLAY_REPO"],
        let boolValue = Bool(envValue)
    {
        return boolValue
    }

    // Default to binary targets approach
    return false
}

/// Enables or disables having Session Replay as a local dependency (needs smartlook-ios-sdk checked out locally)
/// or a remote dependency.
///
/// If the value is `true`, overrides `remoteSessionReplayBranch()`.
///
/// ✅ Feel free to use this flag for local development.
func shouldUseLocalSessionReplayDependency() -> Bool {

    // Check the ENV first
    if let envValue = ProcessInfo.processInfo.environment["USE_LOCAL_SESSION_REPLAY"],
        let boolValue = Bool(envValue)
    {
        return boolValue
    }

    return false
}

/// Sets remote dependency git branch.
func remoteSessionReplayBranch() -> String {

    // Check the ENV first
    if let environmentBranch = ProcessInfo.processInfo.environment["SESSION_REPLAY_BRANCH"] {
        return environmentBranch
    }

    return "develop"
}

/// Local path to Session Replay repository.
func localSessionReplayPath() -> String {

    // Check the ENV first
    if let environmentPath = ProcessInfo.processInfo.environment["SESSION_REPLAY_LOCAL_PATH"] {
        return environmentPath
    }

    return "../../smartlook-ios-sdk-private"
}

/// SessionReplay SPM dependency resolution.
///
/// ⚠️ This function automatically determines the dependency strategy and adds the appropriate
/// dependency to the package. It supports environment variables for CI/CD.
func resolveSessionReplayRepositoryDependency() {

    // Only add repository dependency if using repository strategy
    guard shouldUseSessionReplayAsRepositoryDependency() else {
        return
    }

    // Session replay git repo URL
    let packageGitUrl = "git@github.com:smartlook/smartlook-ios-sdk-private.git"

    // Local dependency has highest priority
    if shouldUseLocalSessionReplayDependency() {
        package.dependencies.append(
            .package(name: "smartlook-ios-sdk-private", path: localSessionReplayPath())
        )
        return
    }

    // Remote dependency with branch
    let branch = remoteSessionReplayBranch()
    package.dependencies.append(
        .package(url: packageGitUrl, branch: branch)
    )
}


// MARK: - ENV var documentation

/*
 Environment Variables for Configuration:

 USE_SESSION_REPLAY_REPO (Bool):
   - true: Use repository-based dependencies (products from smartlook-ios-sdk-private)
   - false: Use binary targets with wrapper approach (default)

 USE_LOCAL_SESSION_REPLAY (Bool):
   - true: Use local path dependency (for development)
   - false: Use remote repository dependency (default when USE_SESSION_REPLAY_REPO=true)

 SESSION_REPLAY_BRANCH (String):
   - Specifies the git branch to use for remote repository dependency
   - Default: "develop"
*/
