// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import class Foundation.ProcessInfo
import PackageDescription

let package = Package(
    name: "SplunkOpenTelemetryBackgroundExporter",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .visionOS(.v1)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SplunkOpenTelemetryBackgroundExporter",
            targets: [
                "SplunkOpenTelemetryBackgroundExporter"
            ])
    ],
    dependencies: [
        sessionReplayDependency(),
        .package(name: "SplunkLogger", path: "../SplunkLogger"),
        .package(
            url: "https://github.com/open-telemetry/opentelemetry-swift",
            exact: "1.12.1"
        )
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SplunkOpenTelemetryBackgroundExporter",
            dependencies: [
                "SplunkLogger",
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift"),
                .product(name: "OpenTelemetryProtocolExporter", package: "opentelemetry-swift"),
                .product(name: "CiscoDiskStorage", package: "smartlook-ios-sdk-private")
            ]),

        .testTarget(
            name: "SplunkOpenTelemetryBackgroundExporterTests",
            dependencies: ["SplunkOpenTelemetryBackgroundExporter"])
    ]
)

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
