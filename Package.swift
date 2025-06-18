// swift-tools-version: 5.9

import class Foundation.ProcessInfo
import PackageDescription

// MARK: - Package and target definitions

// Create the package instance base.
let package = Package(
    name: "SplunkAgent",
    platforms: [
        .iOS(.v15),
        .tvOS(.v15),
        .visionOS(.v1),
        .macCatalyst(.v13)
    ],
    products: [
        .library(
            name: "SplunkAgent",
            targets: ["SplunkAgent"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/open-telemetry/opentelemetry-swift",
            exact: "1.14.0"
        ),
        .package(
            url:"https://github.com/microsoft/plcrashreporter",
            from: "1.12.0"
        )
    ],
    targets: []
)

//  Modify it based on current dependency resolution and add all targets to the package
package.targets.append(contentsOf: generateBinaryTargets())
package.targets.append(contentsOf: generateWrapperTargets())
package.targets.append(contentsOf: generateMainTargets())

// Conditionally add Session Replay as a repository dependency
resolveSessionReplayRepositoryDependency()


// MARK: - Helpers for target generation

/// Generates the main library targets
func generateMainTargets() -> [Target] {
    return [

        // MARK: Splunk Agent

        .target(
            name: "SplunkAgent",
            dependencies: [
                "SplunkCommon",
                "SplunkCrashReports",
                "SplunkSessionReplayProxy",
                "SplunkNetwork",
                "SplunkNetworkMonitor",
                "SplunkSlowFrameDetector",
                "SplunkOpenTelemetry",
                "SplunkAppStart",
                "SplunkWebView",
                "SplunkWebViewProxy",
                resolveDependency("logger")
            ],
            path: "SplunkAgent",
            sources: ["Sources"],
            resources: [
                .copy("Resources/PrivacyInfo.xcprivacy"),
                .copy("Resources/NOTICES")
            ]
        ),
        .testTarget(
            name: "SplunkAgentTests",
            dependencies: ["SplunkAgent", "SplunkCommon"],
            path: "SplunkAgent/Tests",
            resources: [
                .copy("SplunkAgentTests/Testing Support/Assets/v.mp4"),
                .copy("SplunkAgentTests/Testing Support/Mock Data/AlternativeRemoteConfiguration.json"),
                .copy("SplunkAgentTests/Testing Support/Mock Data/RemoteConfiguration.json"),
                .copy("SplunkAgentTests/Testing Support/Mock Data/RemoteError.json")
            ],
            swiftSettings: [.define("SPM_TESTS")]
        ),


        // MARK: - Splunk Network

        .target(
            name: "SplunkNetwork",
            dependencies: [
                "SplunkCommon",
                "SplunkOpenTelemetry"
            ],
            path: "SplunkNetwork/Sources"
        ),
        .testTarget(
            name: "SplunkNetworkTests",
            dependencies: ["SplunkNetwork"],
            path: "SplunkNetwork/Tests"
        ),
        
        
        // MARK: - Splunk Network Monitor

        .target(
            name: "SplunkNetworkMonitor",
            dependencies: [
                "SplunkCommon",
                "SplunkOpenTelemetry"
            ],
            path: "SplunkNetworkMonitor/Sources"
        ),
        .testTarget(
            name: "SplunkNetworkMonitorTests",
            dependencies: ["SplunkNetworkMonitor"],
            path: "SplunkNetworkMonitor/Tests"
        ),
        
        
        // MARK: - Splunk Common
        
        .target(
            name: "SplunkCommon",
            path: "SplunkCommon/Sources"
        ),
        .testTarget(
            name: "SplunkCommonTests",
            dependencies: ["SplunkCommon"],
            path: "SplunkCommon/Tests"
        ),


        // MARK: - Splunk Slow Frame Detector

        .target(
            name: "SplunkSlowFrameDetector",
            dependencies: [
                .byName(name: "SplunkCommon"),
                "SplunkOpenTelemetry"
            ],
            path: "SplunkSlowFrameDetector/Sources"
        ),
        .testTarget(
            name: "SplunkSlowFrameDetectorTests",
            dependencies: ["SplunkSlowFrameDetector", "SplunkCommon"],
            path: "SplunkSlowFrameDetector/Tests"
        ),


        // MARK: - Splunk Custom Data

        .target(
            name: "SplunkCustomData",
            dependencies: [
                "SplunkCommon"
            ],
            path: "SplunkCustomData/Sources"
        ),
        .testTarget(
            name: "SplunkCustomDataTests",
            dependencies: ["SplunkCustomData"],
            path: "SplunkCustomData/Tests"
        ),


        // MARK: - Splunk Error Reporting

        .target(
            name: "SplunkErrorReporting",
            dependencies: [
                "SplunkCommon"
            ],
            path: "SplunkErrorReporting/Sources"
        ),
        .testTarget(
            name: "SplunkErrorReportingTests",
            dependencies: ["SplunkErrorReporting"],
            path: "SplunkErrorReporting/Tests"
        ),


        // MARK: - SplunkCrashReports

        .target(
            name: "SplunkCrashReports",
            dependencies: [
                "SplunkOpenTelemetry",
                "SplunkCommon",
                .product(name: "CrashReporter", package: "PLCrashReporter")
            ],
            path: "SplunkCrashReports/Sources"
        ),
        .testTarget(
            name: "SplunkCrashReportsTests",
            dependencies: [
                "SplunkCrashReports",
                "SplunkCommon",
                .product(name: "CrashReporter", package: "PLCrashReporter")
            ],
            path: "SplunkCrashReports/Tests"
        ),


        // MARK: - Splunk Otel

        .target(
            name: "SplunkOpenTelemetry",
            dependencies: [
                "SplunkOpenTelemetryBackgroundExporter",
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift"),
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift"),
                .product(name: "URLSessionInstrumentation", package: "opentelemetry-swift"),
                .product(name: "ResourceExtension", package: "opentelemetry-swift"),
                .product(name: "SignPostIntegration", package: "opentelemetry-swift"),
                resolveDependency("logger")
            ],
            path: "SplunkOpenTelemetry/Sources"
        ),
        .testTarget(
            name: "SplunkOpenTelemetryTests",
            dependencies: ["SplunkOpenTelemetry", "SplunkCommon"],
            path: "SplunkOpenTelemetry/Tests"
        ),


        // MARK: - Splunk OTel Background Exporter
        
        .target(
            name: "SplunkOpenTelemetryBackgroundExporter",
            dependencies: [
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift"),
                .product(name: "OpenTelemetryProtocolExporter", package: "opentelemetry-swift"),
                resolveDependency("logger"),
                resolveDependency("diskStorage")
            ],
            path: "SplunkOpenTelemetryBackgroundExporter/Sources"
        ),
        .testTarget(
            name: "SplunkOpenTelemetryBackgroundExporterTests",
            dependencies: ["SplunkOpenTelemetryBackgroundExporter", "SplunkCommon"],
            path: "SplunkOpenTelemetryBackgroundExporter/Tests"
        ),


        // MARK: - Splunk App Start
        
        .target(
            name: "SplunkAppStart",
            dependencies: [
                "SplunkCommon",
                "SplunkOpenTelemetry",
                resolveDependency("logger")
            ],
            path: "SplunkAppStart/Sources"
        ),
        .testTarget(
            name: "SplunkAppStartTests",
            dependencies: [
                "SplunkAppStart",
                "SplunkCommon",
                "SplunkOpenTelemetry",
                resolveDependency("logger")
            ],
            path: "SplunkAppStart/Tests"
        ),


        // MARK: - Splunk Web Instrumentation

        .target(
            name: "SplunkWebView",
            dependencies: [
                "SplunkCommon",
                "SplunkOpenTelemetry",
                resolveDependency("logger")
            ],
            path: "SplunkWebView/Sources"
        ),
        .testTarget(
            name: "SplunkWebViewTests",
            dependencies: [
                "SplunkWebView",
            ],
            path: "SplunkWebView/Tests"
        ),


        // MARK: - Splunk Web Instrumentation Proxy

        .target(
            name: "SplunkWebViewProxy",
            dependencies: [
                "SplunkCommon",
                "SplunkOpenTelemetry",
                "SplunkWebView",
                resolveDependency("logger")
            ],
            path: "SplunkWebViewProxy/Sources"
        ),
        .testTarget(
            name: "SplunkWebViewProxyTests",
            dependencies: [
                "SplunkCommon",
                "SplunkOpenTelemetry",
                "SplunkWebView",
                "SplunkWebViewProxy",
                resolveDependency("logger")
            ],
            path: "SplunkWebViewProxy/Tests"
        ),


        // MARK: - Session Replay Proxy

        .target(
            name: "SplunkSessionReplayProxy",
            dependencies: [
                "SplunkCommon",
                resolveDependency("sessionReplay")
            ],
            path: "SplunkSessionReplayProxy/Sources"
        ),
        .testTarget(
            name: "SplunkSessionReplayProxyTests",
            dependencies: ["SplunkSessionReplayProxy"],
            path: "SplunkSessionReplayProxy/Tests"
        )
    ]
}

/// Generates binary targets from the registry, based on the current `DependencyResolutionStrategy`.
func generateBinaryTargets() -> [Target] {
    
    // First check the deps resolution whether we want to generate.
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

    // First check the deps resolution whether we want to generate.
    guard DependencyResolutionStrategy.current == .binaryTargets else {
        return []
    }

    return generateBinaryWrapperTargets()
}

/// Generates wrapper targets that depend on binary targets to correctly construct and link their dependency trees.
func generateBinaryWrapperTargets() -> [Target] {
    return [
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
            url: "https://sdk.smartlook.com/splunk-agent-test/ios/logger-ios-sdk-1.0.1.zip",
            checksum: "403cf7060207186c0d5a26a01fff0a1a4647cc81b608feb4eeb9230afa1e7b16",
            productName: "CiscoLogger",
            wrapperName: "CiscoLoggerWrapper"
        ),
        "encryptor": BinaryTargetInfo(
            name: "CiscoEncryption",
            url: "https://sdk.smartlook.com/splunk-agent-test/ios/encryption-ios-sdk-1.0.254.zip",
            checksum: "236d2ae950c7decb528d8290359c58c22c662cdc1e42899d7544edd9760d893c",
            productName: "CiscoEncryption",
            wrapperName: "CiscoEncryptionWrapper"
        ),
        "swizzling": BinaryTargetInfo(
            name: "CiscoSwizzling",
            url: "https://sdk.smartlook.com/splunk-agent-test/ios/swizzling-ios-sdk-1.0.254.zip",
            checksum: "a6cd8fb5c463bb9e660f560acfa5b33e4c5271fda222047b417bd531a8c0c956",
            productName: "CiscoSwizzling",
            wrapperName: "CiscoSwizzlingWrapper"
        ),
        "interactions": BinaryTargetInfo(
            name: "CiscoInteractions",
            url: "https://sdk.smartlook.com/splunk-agent-test/ios/interactions-ios-sdk-1.0.254.zip",
            checksum: "65c53ade295f34ad7876919f935f428b2ebb016236b21add72b5946a9f57789c",
            productName: "CiscoInteractions",
            wrapperName: "CiscoInteractionsWrapper"
        ),
        "diskStorage": BinaryTargetInfo(
            name: "CiscoDiskStorage",
            url: "https://sdk.smartlook.com/splunk-agent-test/ios/disk-storage-ios-sdk-1.0.254.zip",
            checksum: "1b47895f1793a690ce68fca431e72f689a38470423af392e9785135e514d93de",
            productName: "CiscoDiskStorage",
            wrapperName: "CiscoDiskStorageWrapper"
        ),
        "sessionReplay": BinaryTargetInfo(
            name: "CiscoSessionReplay",
            url: "https://sdk.smartlook.com/splunk-agent-test/ios/session-replay-ios-sdk-1.0.6.254.zip",
            checksum: "d1cf5141c4710fcd5af8c957aa57e319c7f28ee338cc64e6f7283f19aaa66a71",
            productName: "CiscoSessionReplay",
            wrapperName: "CiscoSessionReplayWrapper"
        ),
        "instanceManager": BinaryTargetInfo(
            name: "CiscoInstanceManager",
            url: "https://sdk.smartlook.com/splunk-agent-test/ios/instance-manager-ios-sdk-1.0.254.zip",
            checksum: "fe0bc116914ef408ac2e015aa0fa482774a35868cf803f19a7e593bbaeae6ef3",
            productName: "CiscoInstanceManager",
            wrapperName: "CiscoInstanceManagerWrapper"
        ),
        "runtimeCache": BinaryTargetInfo(
            name: "CiscoRuntimeCache",
            url: "https://sdk.smartlook.com/splunk-agent-test/ios/runtime-cache-ios-sdk-1.0.254.zip",
            checksum: "4bed11f441350f9b52726b2d8e88f1647bd702325e5128d956eb814b05ea028b",
            productName: "CiscoRuntimeCache",
            wrapperName: "CiscoRuntimeCacheWrapper"
        )
    ]
}

/// Determines which dependency resolution strategy to use.
/// Defaults to `.binaryTargets`, present in the `current` property.
enum DependencyResolutionStrategy {

    /// SessionReplay dependencies are linked as binary targets
    /// fetched from S3 storage.
    case binaryTargets

    /// SessionReplay dependencies are linked as products
    /// from a SPM-linked SR repository.
    case repositoryDependency

    static var current: DependencyResolutionStrategy {
        if shouldUseSessionReplayAsRepositoryDependency() {
            return .repositoryDependency
        } else {
            return .binaryTargets
        }
    }
}

/// Resolves a dependency based on the current strategy
/// - Parameter key: The key from SessionReplayBinaryRegistry.targets
/// - Returns: A dependency reference (either wrapper target name or product reference)
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
/// This is the main switch between binary targets and repository-based approach.
func shouldUseSessionReplayAsRepositoryDependency() -> Bool {

    // Check the ENV first
    if let envValue = ProcessInfo.processInfo.environment["USE_SESSION_REPLAY_REPO"],
       let boolValue = Bool(envValue) {
        return boolValue
    }

    // Default to binary targets approach
    return false
}

/// Enables or disables having Session Replay as a local dependency (needs smartlook-ios-sdk checked out locally)
/// or a remote dependency. If the value is `true`, overrides `remoteSessionReplayBranch()`.
///
/// ✅ Feel free to use this flag for local development.
func shouldUseLocalSessionReplayDependency() -> Bool {

    // Check the ENV first
    if let envValue = ProcessInfo.processInfo.environment["USE_LOCAL_SESSION_REPLAY"],
       let boolValue = Bool(envValue) {
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
