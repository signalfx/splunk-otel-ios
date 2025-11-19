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
        .package(
            url: "https://github.com/open-telemetry/opentelemetry-swift",
            exact: "2.0.0"
        ),
        .package(
            url: "https://github.com/microsoft/plcrashreporter",
            from: "1.12.0"
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
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift"),
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift"),
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
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift"),
                resolveDependency("logger"),
                resolveDependency("swizzling")
            ],
            path: "SplunkNavigation/Sources",
            plugins: lintTargetPlugins()
        ),
        .testTarget(
            name: "SplunkNavigationTests",
            dependencies: [
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
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift"),
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift"),
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
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift"),
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
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift")
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
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift"),
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
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift"),
                .product(name: "CrashReporter", package: "PLCrashReporter")
            ],
            path: "SplunkCrashReports/Sources",
            plugins: lintTargetPlugins()
        ),


        // MARK: - Splunk OTel

        .target(
            name: "SplunkOpenTelemetry",
            dependencies: [
                "SplunkOpenTelemetryBackgroundExporter",
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift"),
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift"),
                .product(name: "OpenTelemetryProtocolExporter", package: "opentelemetry-swift"),
                resolveDependency("logger")
            ],
            path: "SplunkOpenTelemetry/Sources",
            plugins: lintTargetPlugins()
        ),


        // MARK: - Splunk OTel Background Exporter

        .target(
            name: "SplunkOpenTelemetryBackgroundExporter",
            dependencies: [
                "SplunkCommon",
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift"),
                .product(name: "OpenTelemetryProtocolExporter", package: "opentelemetry-swift"),
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
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift"),
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
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift"),
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
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift"),
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
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift"),
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift")
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
            dependencies: ["CiscoSwizzling"],
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
        "logger": BinaryTargetInfo(
            name: "CiscoLogger",
            url: "https://sdk.smartlook.com/cisco-session-replay/ios/1.0.6/mh_dylib/cisco-logger-1.0.6.257.zip",
            checksum: "1ff13108b14550f595a07cc729efecbb28baade3f533a94d0c4cacebfcdabe6a",
            productName: "CiscoLogger",
            wrapperName: "CiscoLoggerWrapper"
        ),
        "encryptor": BinaryTargetInfo(
            name: "CiscoEncryption",
            url: "https://sdk.smartlook.com/cisco-session-replay/ios/1.0.6/mh_dylib/cisco-encryption-1.0.6.257.zip",
            checksum: "42cf0a8fc10340bf280fa55c691220cb861e28449de89555a4627d7d8be9ed0c",
            productName: "CiscoEncryption",
            wrapperName: "CiscoEncryptionWrapper"
        ),
        "swizzling": BinaryTargetInfo(
            name: "CiscoSwizzling",
            url: "https://sdk.smartlook.com/cisco-session-replay/ios/1.0.6/mh_dylib/cisco-swizzling-1.0.6.257.zip",
            checksum: "2f955622af50f6a0acc6b8a22977ac965598c7790370e2ed1270787125b9f096",
            productName: "CiscoSwizzling",
            wrapperName: "CiscoSwizzlingWrapper"
        ),
        "interactions": BinaryTargetInfo(
            name: "CiscoInteractions",
            url: "https://sdk.smartlook.com/cisco-session-replay/ios/1.0.6/mh_dylib/cisco-interactions-1.0.6.257.zip",
            checksum: "d82152d09a8b508902f7c0e133f04b06cac2364cf3d033b95b35488256659ab1",
            productName: "CiscoInteractions",
            wrapperName: "CiscoInteractionsWrapper"
        ),
        "diskStorage": BinaryTargetInfo(
            name: "CiscoDiskStorage",
            url: "https://sdk.smartlook.com/cisco-session-replay/ios/1.0.6/mh_dylib/cisco-disk-storage-1.0.6.257.zip",
            checksum: "a70b0e9913313971b60a74b61b43bf58a3968a7156f5479bb98cab3818da6c2d",
            productName: "CiscoDiskStorage",
            wrapperName: "CiscoDiskStorageWrapper"
        ),
        "sessionReplay": BinaryTargetInfo(
            name: "CiscoSessionReplay",
            url: "https://sdk.smartlook.com/cisco-session-replay/ios/1.0.6/mh_dylib/cisco-session-replay-1.0.6.257.zip",
            checksum: "3e13627d481fa2044b9083760d2b634099d067f510bd5dee137415c933fd9597",
            productName: "CiscoSessionReplay",
            wrapperName: "CiscoSessionReplayWrapper"
        ),
        "instanceManager": BinaryTargetInfo(
            name: "CiscoInstanceManager",
            url: "https://sdk.smartlook.com/cisco-session-replay/ios/1.0.6/mh_dylib/cisco-instance-manager-1.0.6.257.zip",
            checksum: "9e13116eefd14a37657dd2bc59c384a99356324dd849cd88f7c9b1a0c18a7f31",
            productName: "CiscoInstanceManager",
            wrapperName: "CiscoInstanceManagerWrapper"
        ),
        "runtimeCache": BinaryTargetInfo(
            name: "CiscoRuntimeCache",
            url: "https://sdk.smartlook.com/cisco-session-replay/ios/1.0.6/mh_dylib/cisco-runtime-cache-1.0.6.257.zip",
            checksum: "4efcc975202b6616739bf41c91380c374a9fd7bd2ddd2747a32b13ec973bff12",
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
