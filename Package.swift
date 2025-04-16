// swift-tools-version: 5.9

import class Foundation.ProcessInfo
import PackageDescription

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
        sessionReplayDependency()
    ],
    targets: [
        
        // MARK: Splunk Agent

        .target(
            name: "SplunkAgent",
            dependencies: [
                "SplunkLogger",
                "SplunkSharedProtocols",
                "SplunkCrashReports",
                "SplunkSessionReplayProxy",
                "SplunkNetwork",
                "SplunkSlowFrameDetector",
                "SplunkOpenTelemetry",
                "SplunkANRReporter",
                "SplunkAppStart",
                "SplunkCustomTracking"
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
            dependencies: ["SplunkAgent"],
            path: "SplunkAgent/Tests",
            resources: [
                .copy("SplunkAgentTests/Testing Support/Assets/v.mp4"),
                .copy("SplunkAgentTests/Testing Support/Mock Data/AlternativeRemoteConfiguration.json"),
                .copy("SplunkAgentTests/Testing Support/Mock Data/RemoteConfiguration.json"),
                .copy("SplunkAgentTests/Testing Support/Mock Data/RemoteError.json")
            ],
            swiftSettings: [.define("SPM_TESTS")]
        ),
        
        
        // MARK: Splunk Logger
        
        .target(
            name: "SplunkLogger",
            path: "SplunkLogger/Sources"
        ),
        .testTarget(
            name: "SplunkLoggerTests",
            dependencies: ["SplunkLogger"],
            path: "SplunkLogger/Tests"
        ),
        
        
        // MARK: Splunk Network
        
        .target(
            name: "SplunkNetwork",
            dependencies: [
                "SplunkSharedProtocols",
                "SplunkOpenTelemetry"
            ],
            path: "SplunkNetwork/Sources"
        ),
        .testTarget(
            name: "SplunkNetworkTests",
            dependencies: ["SplunkNetwork"],
            path: "SplunkNetwork/Tests"
        ),
        
        
        // MARK: Splunk ANR Reporter
        
        .target(
            name: "SplunkANRReporter",
            dependencies: [
                "SplunkSharedProtocols"
            ],
            path: "SplunkANRReporter/Sources"
        ),
        .testTarget(
            name: "SplunkANRReporterTests",
            dependencies: ["SplunkANRReporter"],
            path: "SplunkANRReporter/Tests"
        ),
        
        
        // MARK: Splunk Shared Protocols
        
        .target(
            name: "SplunkSharedProtocols",
            path: "SplunkSharedProtocols/Sources"
        ),
        .testTarget(
            name: "SplunkSharedProtocolsTests",
            dependencies: ["SplunkSharedProtocols"],
            path: "SplunkSharedProtocols/Tests"
        ),
        
        
        // MARK: Splunk Slow Frame Detector
        
        .target(
            name: "SplunkSlowFrameDetector",
            dependencies: [
                .byName(name: "SplunkSharedProtocols"),
                "SplunkOpenTelemetry"
            ],
            path: "SplunkSlowFrameDetector/Sources"
        ),
        .testTarget(
            name: "SplunkSlowFrameDetectorTests",
            dependencies: ["SplunkSlowFrameDetector", "SplunkSharedProtocols"],
            path: "SplunkSlowFrameDetector/Tests"
        ),
        
        
        // MARK: Splunk Custom Tracking

        .target(
            name: "SplunkCustomTracking",
            dependencies: [
                "SplunkLogger",
                "SplunkOpenTelemetry",
                "SplunkSharedProtocols"
            ],
            path: "SplunkCustomTracking/Sources",
        ),
        .testTarget(
            name: "SplunkCustomTrackingTests",
            dependencies: ["SplunkCustomTracking"],
            path: "SplunkCustomTracking/Tests"
        ),
        
        
        // MARK: SplunkCrashReporter
        
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
        
        
        // MARK: SplunkCrashReports
        
        .target(
            name: "SplunkCrashReports",
            dependencies: [
                "SplunkCrashReporter",
                "SplunkOpenTelemetry",
                "SplunkSharedProtocols"
            ],
            path: "SplunkCrashReports/Sources"
        ),
        .testTarget(
            name: "SplunkCrashReportsTests",
            dependencies: ["SplunkCrashReports", "SplunkSharedProtocols"],
            path: "SplunkCrashReports/Tests"
        ),
        
        
        // MARK: Splunk Otel
        
        .target(
            name: "SplunkOpenTelemetry",
            dependencies: [
                "SplunkOpenTelemetryBackgroundExporter",
                "SplunkLogger",
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift"),
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift"),
                .product(name: "URLSessionInstrumentation", package: "opentelemetry-swift"),
                .product(name: "ResourceExtension", package: "opentelemetry-swift"),
                .product(name: "SignPostIntegration", package: "opentelemetry-swift")
            ],
            path: "SplunkOpenTelemetry/Sources"
        ),
        .testTarget(
            name: "SplunkOpenTelemetryTests",
            dependencies: ["SplunkOpenTelemetry", "SplunkSharedProtocols"],
            path: "SplunkOpenTelemetry/Tests"
        ),
        
        
        // MARK: Splunk OTel Background Exporter
        
        .target(
            name: "SplunkOpenTelemetryBackgroundExporter",
            dependencies: [
                "SplunkLogger",
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift"),
                .product(name: "OpenTelemetryProtocolExporter", package: "opentelemetry-swift")
            ],
            path: "SplunkOpenTelemetryBackgroundExporter/Sources"
        ),
        .testTarget(
            name: "SplunkOpenTelemetryBackgroundExporterTests",
            dependencies: ["SplunkOpenTelemetryBackgroundExporter"],
            path: "SplunkOpenTelemetryBackgroundExporter/Tests"
        ),
        
        
        // MARK: Splunk App Start
        
        .target(
            name: "SplunkAppStart",
            dependencies: [
                "SplunkSharedProtocols",
                "SplunkLogger",
                "SplunkOpenTelemetry"
            ],
            path: "SplunkAppStart/Sources"
        ),
        .testTarget(
            name: "SplunkAppStartTests",
            dependencies: [
                "SplunkAppStart",
                "SplunkSharedProtocols",
                "SplunkLogger",
                "SplunkOpenTelemetry"
            ],
            path: "SplunkAppStart/Tests"
        ),
        
        
        // MARK: Session Replay Proxy
        
        .target(
            name: "SplunkSessionReplayProxy",
            dependencies: [
                "SplunkSharedProtocols",
                .product(name: "CiscoSessionReplay", package: "smartlook-ios-sdk-private")
            ],
            path: "SplunkSessionReplayProxy/Sources"
        ),
        .testTarget(
            name: "SplunkSessionReplayProxyTests",
            dependencies: ["SplunkSessionReplayProxy"],
            path: "SplunkSessionReplayProxy/Tests"
        )
    ]
)


// MARK: Session Replay related helpers

/// Enables or disables having Session Replay as a local dependency (needs smartlook-ios-sdk checked out locally)
/// or a remote dependency. If the value is `true`, overrides `remoteSessionReplayBranch()`.
///
/// ✅ Feel free to use this flag for local development.
func shouldUseLocalSessionReplayDependency() -> Bool {
    return false
}

/// Sets remote dependency git branch.
///
/// ✅ Feel free to use this for development.
func remoteSessionReplayBranch() -> String {
    return "develop"
}

/// SessionReplay swift package dependendency.
///
/// ⚠️ Don't touch this function. This function makes sure that our build script uses "main" branch during release process.
func sessionReplayDependency() -> Package.Dependency {
    // Session replay git repo
    let packageGitUrl = "git@github.com:smartlook/smartlook-ios-sdk-private.git"
    
    // Check if a branch was set as an environment variable.
    // Atm it's set in a build script in Tools/build_frameworks/050-Xarchives.sh
    if let environmentBranch = ProcessInfo.processInfo.environment["SESSION_REPLAY_BRANCH"] {
        return .package(url: packageGitUrl, branch: environmentBranch)
    }
    
    // Local dependency, enables SessionReplay local development, needs smartlook-ios-sdk checked out locally
    if shouldUseLocalSessionReplayDependency() {
        return .package(name: "smartlook-ios-sdk-private", path: "../../smartlook-ios-sdk-private")
    }
    
    return .package(url: packageGitUrl, branch: remoteSessionReplayBranch())
}
