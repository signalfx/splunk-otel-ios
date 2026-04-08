// swift-tools-version: 5.9

// swiftformat:disable sortImports
import PackageDescription

import class Foundation.ProcessInfo

// MARK: - Package and target definitions

/// Create the package instance base.
let package = Package(
    name: "SplunkAgent",
    platforms: [
        .iOS(.v13),
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
        ),
        .package(
            url: "https://github.com/microsoft/plcrashreporter",
            exact: "1.12.0"
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
                "SplunkCrashReports",
                "SplunkSessionReplayProxy",
                "SplunkNavigation",
                "SplunkNetwork",
                "SplunkNetworkMonitor",
                "SplunkSlowFrameDetector",
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
            dependencies: ["SplunkAgent", "SplunkCommon"],
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
                "SplunkInteractions",
                "SplunkNavigation",
                "SplunkNetworkMonitor",
                "SplunkSlowFrameDetector"
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
                "SplunkNavigation"
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
                "SplunkNetwork"
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


        // MARK: - SplunkCrashReports (Instrumentation)

        .target(
            name: "SplunkCrashReports",
            dependencies: [
                "SplunkCommon",
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift-core"),
                .product(name: "CrashReporter", package: "PLCrashReporter")
            ],
            path: "SplunkCrashReports/Sources",
            plugins: lintTargetPlugins()
        ),
        .testTarget(
            name: "SplunkCrashReportsTests",
            dependencies: [
                "SplunkCrashReports",
                "SplunkCommon"
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
            name: "CiscoInstanceManagerWrapper",
            dependencies: ["CiscoInstanceManager", resolveDependency("logger")],
            path: "TargetWrappers/CiscoInstanceManagerWrapper/Sources"
        ),
        .target(
            name: "CiscoRuntimeCacheWrapper",
            dependencies: ["CiscoRuntimeCache", resolveDependency("logger")],
            path: "TargetWrappers/CiscoRuntimeCacheWrapper/Sources"
        ),
        .target(
            name: "CiscoSessionReplayWrapper",
            dependencies: [
                "CiscoSessionReplay",
                resolveDependency("instanceManager"),
                resolveDependency("diskStorage"),
                resolveDependency("runtimeCache"),
                resolveDependency("interactions"),
                resolveDependency("logger"),
                resolveDependency("swizzling")
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
            url: "https://sdk.smartlook.com/cisco-session-replay/ios/1.1.0/staticlib/cisco-common-1.1.0.261.zip",
            checksum: "3475d8ea026fe8ac665bb1fbfd4d875be3663432f6155a44cf18e40449efe3ac",
            productName: "CiscoCommon",
            wrapperName: "CiscoCommonWrapper"
        ),
        "logger": BinaryTargetInfo(
            name: "CiscoLogger",
            url: "https://sdk.smartlook.com/cisco-session-replay/ios/1.1.0/staticlib/cisco-logger-1.1.0.261.zip",
            checksum: "ed2b086e5d9c1b3d713e1d4a78eb4e0af5428969f9dfb609e7fe538b000e55b3",
            productName: "CiscoLogger",
            wrapperName: "CiscoLoggerWrapper"
        ),
        "encryptor": BinaryTargetInfo(
            name: "CiscoEncryption",
            url: "https://sdk.smartlook.com/cisco-session-replay/ios/1.1.0/staticlib/cisco-encryption-1.1.0.261.zip",
            checksum: "483b989b067a8072f4d6ad5f459ed11c80987d481b54977435172cb6368af130",
            productName: "CiscoEncryption",
            wrapperName: "CiscoEncryptionWrapper"
        ),
        "swizzling": BinaryTargetInfo(
            name: "CiscoSwizzling",
            url: "https://sdk.smartlook.com/cisco-session-replay/ios/1.1.0/staticlib/cisco-swizzling-1.1.0.261.zip",
            checksum: "0b4594821fd7572e7962fda16e7afb0d77d63ff13df1209bb3a198585f683e38",
            productName: "CiscoSwizzling",
            wrapperName: "CiscoSwizzlingWrapper"
        ),
        "interactions": BinaryTargetInfo(
            name: "CiscoInteractions",
            url: "https://sdk.smartlook.com/cisco-session-replay/ios/1.1.0/staticlib/cisco-interactions-1.1.0.261.zip",
            checksum: "03b2be871145e4b19489c6fa34a1daaf75eb35f03847bc99ce2bd39d2f263749",
            productName: "CiscoInteractions",
            wrapperName: "CiscoInteractionsWrapper"
        ),
        "diskStorage": BinaryTargetInfo(
            name: "CiscoDiskStorage",
            url: "https://sdk.smartlook.com/cisco-session-replay/ios/1.1.0/staticlib/cisco-disk-storage-1.1.0.261.zip",
            checksum: "89e8bcde2e28550cd0f95962e17c5af8e36bf6d2f24d24ee9e655f4ed2d5b0ba",
            productName: "CiscoDiskStorage",
            wrapperName: "CiscoDiskStorageWrapper"
        ),
        "sessionReplay": BinaryTargetInfo(
            name: "CiscoSessionReplay",
            url: "https://sdk.smartlook.com/cisco-session-replay/ios/1.1.0/staticlib/cisco-session-replay-1.1.0.261.zip",
            checksum: "f5c8a4a635c21e3b87ab861f93e2c70ed47393cbf190310a843518a80e469dfd",
            productName: "CiscoSessionReplay",
            wrapperName: "CiscoSessionReplayWrapper"
        ),
        "instanceManager": BinaryTargetInfo(
            name: "CiscoInstanceManager",
            url: "https://sdk.smartlook.com/cisco-session-replay/ios/1.1.0/staticlib/cisco-instance-manager-1.1.0.261.zip",
            checksum: "249eb687c03f1fdfc3d3da706504e077752db372d8b3fd597abd9d3f3692fca9",
            productName: "CiscoInstanceManager",
            wrapperName: "CiscoInstanceManagerWrapper"
        ),
        "runtimeCache": BinaryTargetInfo(
            name: "CiscoRuntimeCache",
            url: "https://sdk.smartlook.com/cisco-session-replay/ios/1.1.0/staticlib/cisco-runtime-cache-1.1.0.261.zip",
            checksum: "3af6da9b00697f5ddca5b25a7e04e8e3c5ce6f1be112c0c627726a0a2b50a2a2",
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
