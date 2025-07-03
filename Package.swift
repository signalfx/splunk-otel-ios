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
                "SplunkNavigation",
                "SplunkNetwork",
                "SplunkNetworkMonitor",
                "SplunkSlowFrameDetector",
                "SplunkOpenTelemetry",
                "SplunkInteractions",
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift"),
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift"),
                "SplunkAppStart",
                "SplunkWebView",
                "SplunkWebViewProxy",
                "SplunkCustomTracking",
                resolveDependency("logger")
            ],
            path: "SplunkAgent/Sources",
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


        // MARK: - Splunk Navigation (Instrumentation)

        .target(
            name: "SplunkNavigation",
            dependencies: [
                "SplunkCommon",
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift"),
                resolveDependency("logger")
            ],
            path: "SplunkNavigation/Sources"
        ),
        .testTarget(
            name: "SplunkNavigationTests",
            dependencies: ["SplunkNavigation"],
            path: "SplunkNavigation/Tests"
        ),


        // MARK: - Splunk Network (Instrumentation)

        .target(
            name: "SplunkNetwork",
            dependencies: [
                "SplunkCommon",
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift"),
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift"),
                .product(name: "ResourceExtension", package: "opentelemetry-swift"),
                .product(name: "URLSessionInstrumentation", package: "opentelemetry-swift"),
                .product(name: "SignPostIntegration", package: "opentelemetry-swift")
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
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift"),
                resolveDependency("logger")
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
            dependencies: [
                resolveDependency("diskStorage"),
                resolveDependency("encryptor")
            ],
            path: "SplunkCommon/Sources"
        ),
        .testTarget(
            name: "SplunkCommonTests",
            dependencies: ["SplunkCommon"],
            path: "SplunkCommon/Tests"
        ),


        // MARK: - Splunk Slow Frame Detector (Instrumentation)

        .target(
            name: "SplunkSlowFrameDetector",
            dependencies: [
                .byName(name: "SplunkCommon"),
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift")
            ],
            path: "SplunkSlowFrameDetector/Sources"
        ),
        .testTarget(
            name: "SplunkSlowFrameDetectorTests",
            dependencies: ["SplunkSlowFrameDetector", "SplunkCommon"],
            path: "SplunkSlowFrameDetector/Tests"
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
            cSettings: [
                .define("PLCR_PRIVATE"),
                .define("PLCF_RELEASE_BUILD"),
                .define("PLCRASHREPORTER_PREFIX", to: "SPLK"),
                .define("SWIFT_PACKAGE"), // Should be defined by default, Xcode 11.1 workaround.
                .headerSearchPath("Dependencies/protobuf-c"),
                .unsafeFlags(["-w"]) // Suppresses "Implicit conversion" warnings in protobuf.c
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
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift"),
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
                "SplunkCommon",
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


        // MARK: - Splunk Interactions

        .target(
                name: "SplunkInteractions",
                dependencies: [
                    "SplunkCommon",
                    .product(name: "OpenTelemetryApi", package: "opentelemetry-swift"),
                    resolveDependency("runtimeCache"),
                    resolveDependency("logger")
                ],
                path: "SplunkInteractions/Sources"
            ),
        .testTarget(
            name: "SplunkInteractionsTests",
            dependencies: ["SplunkInteractions"],
            path: "SplunkInteractions/Tests"
        ),


        // MARK: - Splunk App Start (Instrumentation)

        .target(
            name: "SplunkAppStart",
            dependencies: [
                "SplunkCommon",
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift"),
                resolveDependency("logger")
            ],
            path: "SplunkAppStart/Sources"
        ),
        .testTarget(
            name: "SplunkAppStartTests",
            dependencies: [
                "SplunkAppStart"
            ],
            path: "SplunkAppStart/Tests"
        ),


        // MARK: - Splunk Web (Instrumentation)

        .target(
            name: "SplunkWebView",
            dependencies: [
                "SplunkCommon",
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
                "SplunkWebView"
            ],
            path: "SplunkWebViewProxy/Sources"
        ),
        .testTarget(
            name: "SplunkWebViewProxyTests",
            dependencies: [
                "SplunkWebViewProxy"
            ],
            path: "SplunkWebViewProxy/Tests"
        ),


        // MARK: - Splunk Custom Tracking
        
        .target(
            name: "SplunkCustomTracking",
            dependencies: [
                "SplunkCommon",
                "SplunkOpenTelemetry",
                resolveDependency("logger")
            ],
            path: "SplunkCustomTracking/Sources"
        ),
        .testTarget(
            name: "SplunkCustomTrackingTests",
            dependencies: [
                "SplunkCommon",
                "SplunkOpenTelemetry",
                "SplunkCustomTracking",
                resolveDependency("logger")
            ],
            path: "SplunkCustomTracking/Tests"
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
            url: "https://sdk.smartlook.com/cisco-session-replay/ios/1.0.6/mh_dylib/cisco-logger-1.0.6.255.zip",
            checksum: "d404caf437180d12dc3bbcef9567bce811268d671ca09a484cf8df51114d7777",
            productName: "CiscoLogger",
            wrapperName: "CiscoLoggerWrapper"
        ),
        "encryptor": BinaryTargetInfo(
            name: "CiscoEncryption",
            url: "https://sdk.smartlook.com/cisco-session-replay/ios/1.0.6/mh_dylib/cisco-encryption-1.0.6.255.zip",
            checksum: "4ddd3985b87102e9190649f4b9d655ffe2380f51d6e12ddc170cc414a333a4b9",
            productName: "CiscoEncryption",
            wrapperName: "CiscoEncryptionWrapper"
        ),
        "swizzling": BinaryTargetInfo(
            name: "CiscoSwizzling",
            url: "https://sdk.smartlook.com/cisco-session-replay/ios/1.0.6/mh_dylib/cisco-swizzling-1.0.6.255.zip",
            checksum: "a1581f336935215a54d74a1c208ed69213c23c4a3f9b7f4a5b6276d9d4e31790",
            productName: "CiscoSwizzling",
            wrapperName: "CiscoSwizzlingWrapper"
        ),
        "interactions": BinaryTargetInfo(
            name: "CiscoInteractions",
            url: "https://sdk.smartlook.com/cisco-session-replay/ios/1.0.6/mh_dylib/cisco-interactions-1.0.6.255.zip",
            checksum: "63e7821824a58fdae5743a58d4d4ae3f32ef2f0c0e8e38e2d80742677e455877",
            productName: "CiscoInteractions",
            wrapperName: "CiscoInteractionsWrapper"
        ),
        "diskStorage": BinaryTargetInfo(
            name: "CiscoDiskStorage",
            url: "https://sdk.smartlook.com/cisco-session-replay/ios/1.0.6/mh_dylib/cisco-disk-storage-1.0.6.255.zip",
            checksum: "ac7d6b307d3a7b189561305f4ff2136876453efbfdba331c54cb1362a61e5c05",
            productName: "CiscoDiskStorage",
            wrapperName: "CiscoDiskStorageWrapper"
        ),
        "sessionReplay": BinaryTargetInfo(
            name: "CiscoSessionReplay",
            url: "https://sdk.smartlook.com/cisco-session-replay/ios/1.0.6/mh_dylib/cisco-session-replay-1.0.6.255.zip",
            checksum: "b9b3b0ad315430c637b728ad2a890f3796ba9025a572077d1247f0686f70fd4e",
            productName: "CiscoSessionReplay",
            wrapperName: "CiscoSessionReplayWrapper"
        ),
        "instanceManager": BinaryTargetInfo(
            name: "CiscoInstanceManager",
            url: "https://sdk.smartlook.com/cisco-session-replay/ios/1.0.6/mh_dylib/cisco-instance-manager-1.0.6.255.zip",
            checksum: "a755d542cda53e366c3408c1256a4e8c4a1a49e1f0ff9b2d3f9fea5d25d2b46c",
            productName: "CiscoInstanceManager",
            wrapperName: "CiscoInstanceManagerWrapper"
        ),
        "runtimeCache": BinaryTargetInfo(
            name: "CiscoRuntimeCache",
            url: "https://sdk.smartlook.com/cisco-session-replay/ios/1.0.6/mh_dylib/cisco-runtime-cache-1.0.6.255.zip",
            checksum: "705b69ec9fe687538f193f7585d4372fba00e0197e50fab07b91da64b49cd03a",
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
