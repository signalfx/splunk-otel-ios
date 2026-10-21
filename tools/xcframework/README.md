# XCFramework Build System

Build tooling for producing signed, multi-platform xcframeworks from the Splunk RUM iOS SDK source.

## Quick Start

```bash
# Full build: OTel + dynamic Cisco Session Replay + static Agent modules
export SESSION_REPLAY_LOCAL_PATH=/path/to/session-replay-repo
make build

# iOS-only build: device + simulator slices only
make build IOS_ONLY=true

# Validate all built xcframeworks
make validate

# Build & link a smoke test app
make smoke-test
```

## Build Pipeline

The `make build` target requires `SESSION_REPLAY_LOCAL_PATH` and runs four stages in order:

| Stage | Command | What it does |
|-------|---------|-------------|
| 1 | `make build-otel` | Clones `opentelemetry-swift-core`, generates a Tuist project, and archives `OpenTelemetryApi` + `OpenTelemetrySdk` for all 7 platform slices, or 2 slices with `IOS_ONLY=true` |
| 2 | `make build-cisco` | Builds all 14 Cisco Session Replay frameworks as **dynamic** xcframeworks from the local Session Replay checkout |
| 3 | `make populate-deps` | Stages OTel and already-built dynamic Cisco xcframeworks into `dependencies/` |
| 4 | `make build-agent` | Generates the main Tuist workspace and builds all Splunk modules as static xcframeworks, plus the dynamic vendored `SplunkCrashReporter` |

### Output

All built xcframeworks are placed in `output/xcframeworks/`:

```
output/xcframeworks/
├── OpenTelemetryApi.xcframework
├── OpenTelemetrySdk.xcframework
├── SplunkCrashReporter.xcframework
├── CiscoCommon.xcframework
├── CiscoLogger.xcframework
├── CiscoEncryption.xcframework
├── CiscoSwizzling.xcframework
├── CiscoInteractions.xcframework
├── CiscoDiskStorage.xcframework
├── CiscoVideoEncoder.xcframework
├── CiscoScreenshot.xcframework
├── CiscoWireframe.xcframework
├── CiscoDataExporter.xcframework
├── CiscoSnapshotManager.xcframework
├── CiscoSessionReplay.xcframework
├── CiscoInstanceManager.xcframework
├── CiscoRuntimeCache.xcframework
├── CiscoVideoEncoder.xcframework
├── CiscoScreenshot.xcframework
├── CiscoWireframe.xcframework
├── CiscoDataExporter.xcframework
├── CiscoSnapshotManager.xcframework
├── SplunkAgent.xcframework
├── SplunkAgentObjC.xcframework
├── SplunkCommon.xcframework
├── SplunkNavigation.xcframework
├── SplunkNetwork.xcframework
├── SplunkNetworkMonitor.xcframework
├── SplunkSlowFrameDetector.xcframework
├── SplunkCrashReports.xcframework
├── SplunkOpenTelemetry.xcframework
├── SplunkOpenTelemetryBackgroundExporter.xcframework
├── SplunkInteractions.xcframework
├── SplunkAppStart.xcframework
├── SplunkAppState.xcframework
├── SplunkWebView.xcframework
├── SplunkCustomTracking.xcframework
└── SplunkSessionReplayProxy.xcframework
```

Static framework companion bundles for `SplunkAgent`, `SplunkAgentObjC`, and `SplunkWebView` are built for each supported platform and included under platform-named directories in `output/resources/` and the release archive.

Cisco Session Replay xcframeworks in the binary distribution are built as dynamic frameworks, preserving the distribution model established to address package-resolution issues for T-Mobile integrations. Splunk Agent module xcframeworks remain static for hybrid consumers, including React Native apps using static framework linkage; `SplunkCrashReporter` and OpenTelemetry remain dynamic. `Package.swift` uses a separate registry of published static Cisco binaries, which this build-output setting does not change. The legacy `populate-dependencies.sh --download-cisco` option is disabled until that registry contains all 14 modules.

### Platform Matrix

| Module | iOS | tvOS | visionOS | macCatalyst |
|--------|-----|------|----------|-------------|
| Splunk modules | arm64 | arm64 | arm64 | arm64 |
| Cisco modules | arm64 | arm64 | arm64 | arm64+x86_64 |
| SplunkCrashReports | arm64 | arm64 | -- | arm64 |
| OpenTelemetryApi/Sdk | arm64 | arm64 | arm64 | arm64+x86_64 |
| SplunkCrashReporter | arm64 | arm64 | -- | arm64 |

All platforms also include simulator slices (arm64+x86_64).

macCatalyst slices for agent modules are arm64-only to match Cisco Session Replay xcframeworks.

### Configuration

Key variables in the Makefile:

| Variable | Default | Description |
|----------|---------|-------------|
| `OTEL_VERSION` | `2.3.0` | OpenTelemetry Swift Core tag to build |
| `SESSION_REPLAY_LOCAL_PATH` | *(required)* | Local path to the Session Replay repository |
| `CISCO_MACH_O_TYPE` | `mh_dylib` | Session Replay output type (`mh_dylib` or `staticlib`) |
| `CISCO_XCFRAMEWORKS_PATH` | *(empty)* | Legacy path to prebuilt Cisco xcframeworks |
| `IOS_ONLY` | `false` | Build and validate only `ios-arm64` and `ios-arm64_x86_64-simulator` slices |

---

## Release

The build workflow checks out the private Session Replay repository with read-only access, builds dynamic Cisco and static Agent modules, validates platform slices, and runs the consumer linkage smoke test. Configure the `SESSION_REPLAY_READ_TOKEN` repository secret with read access to `smartlook-ios-sdk-private`. Signed release packaging remains a local process while distribution certificates cannot be stored in GitHub secrets.

### How it works

1. A developer triggers `release.yml` with a version and ticket ID.
2. The release PR is reviewed and merged to `main`.
3. `merge_release.yml` runs automatically — creates a git tag and a GitHub Release.
4. The `build-xcframeworks.yml` workflow builds the distribution from the selected Session Replay ref and uploads the unsigned frameworks and size report.
5. A developer runs `scripts/sign-and-upload.sh` locally with `SESSION_REPLAY_LOCAL_PATH` set to build, sign, validate, package, and upload `SplunkAgent-XCFrameworks.zip`.

`build-xcframeworks.yml` checks out Session Replay source directly and builds the complete static-linking-friendly distribution. Set its `session-replay-ref` input to the branch, tag, or commit being released.

Each build writes `output/size-report.md`, which records overall XCFramework size, the existing Session Replay size, and the contribution from the five new modules. The report is included in the release zip.

### Local signing

Run the convenience script from `tools/xcframework`:

```bash
# Signs and uploads to the release in one step
export SESSION_REPLAY_LOCAL_PATH=/path/to/session-replay-repo
./scripts/sign-and-upload.sh 1.2.0
```

The script will:
- Auto-detect your signing identity from the local keychain
- Build OTel, dynamic Cisco, and Splunk xcframeworks locally
- Record the Session Replay commit, branch, and dirty state in `cisco-release-manifest.txt`
- Sign non-Cisco xcframeworks while preserving pre-signed Cisco framework signatures
- Validate signatures for all shipped xcframeworks
- Package and upload the zip to the existing GitHub release

#### Options

```bash
# Legacy: use a specific CI run with prebuilt Cisco artifacts
./scripts/sign-and-upload.sh 1.2.0 --run-id 12345678

# Use a specific signing identity
./scripts/sign-and-upload.sh 1.2.0 --identity "Apple Distribution: Splunk Inc. (TEAMID)"

# Sign and package without uploading (dry run)
export SESSION_REPLAY_LOCAL_PATH=/path/to/session-replay-repo
./scripts/sign-and-upload.sh 1.2.0 --skip-upload

# Build, sign, package, and upload the iOS-only distribution
./scripts/sign-and-upload.sh 1.2.0 --ios-only

# Upload to a release tag that differs from the version recorded in the manifest
./scripts/sign-and-upload.sh 1.2.0 --upload-to v1.2.0
```

The normal package is named `SplunkAgent-XCFrameworks.zip`. The iOS-only package is named `SplunkAgent-XCFrameworks-iOS-only.zip`.

#### Prerequisites

- Apple distribution certificate installed in your local keychain
- `SESSION_REPLAY_LOCAL_PATH` set to a local Session Replay repository checkout
- `gh` CLI installed and authenticated only for upload mode or legacy `--run-id` mode

### Manual step-by-step (alternative)

If you prefer to run each step individually:

```bash
# 1. Build all unsigned xcframeworks locally
export SESSION_REPLAY_LOCAL_PATH=/path/to/session-replay-repo
make clean build

# 2. Find your signing identity
security find-identity -v -p codesigning

# 3. Sign non-Cisco xcframeworks
./scripts/sign-xcframeworks.sh "Apple Distribution: Splunk Inc. (TEAMID)"

# 4. Validate all signatures
RELEASE=true ./scripts/validate-xcframeworks.sh

# 5. Package and upload to the existing release
./scripts/release.sh 1.2.0 --upload-to 1.2.0
```

For an iOS-only manual build, pass `IOS_ONLY=true` to `make build`, `make validate`, and `scripts/release.sh --ios-only`.

---

## Customer Integration Guide

### Adding XCFrameworks to Your Xcode Project

1. **Download** the release `.zip` and extract it. You will have a folder containing all `.xcframework` bundles.

2. **Drag and drop** all `.xcframework` bundles and the three resource bundles from the directory under `resources/` matching the app target's platform (for example, `resources/ios/` for iOS device builds or `resources/tvos/` for tvOS).

3. For each target that uses Splunk RUM, go to **General > Frameworks, Libraries, and Embedded Content**. Set the static Splunk Agent module frameworks to **Do Not Embed**. Set the dynamic Cisco, `OpenTelemetryApi`, `OpenTelemetrySdk`, and `SplunkCrashReporter` frameworks to **Embed & Sign**. Ensure the three matching platform resource bundles appear in the app target's **Build Phases > Copy Bundle Resources**; static frameworks do not carry them into the app automatically.

4. **Import** the SDK in your code:

```swift
import SplunkAgent

// Initialize in your app delegate or @main App init:
let endpoint = EndpointConfiguration(
    realm: "us0",
    rumAccessToken: "<your-rum-token>"
)

let config = AgentConfiguration(
    endpoint: endpoint,
    appName: "MyApp",
    deploymentEnvironment: "production"
)

try SplunkRum.initialize(with: config)
```

### Required Frameworks

At a minimum, you need these frameworks:

| Framework | Purpose |
|-----------|---------|
| `SplunkAgent.xcframework` | Main SDK and public API |
| `resources/<platform>/SplunkAgentXCFrameworks_SplunkAgent.bundle` | Privacy manifest and notices for the Swift SDK |
| `resources/<platform>/SplunkAgentXCFrameworks_SplunkAgentObjC.bundle` | Privacy manifest and notices for the Objective-C SDK |
| `resources/<platform>/SplunkAgentXCFrameworks_SplunkWebView.bundle` | JavaScript injected by `SplunkWebView` |
| `SplunkCommon.xcframework` | Shared types and protocols |
| `SplunkOpenTelemetry.xcframework` | OpenTelemetry integration |
| `SplunkOpenTelemetryBackgroundExporter.xcframework` | OTLP export with background support |
| `OpenTelemetryApi.xcframework` | OpenTelemetry API |
| `OpenTelemetrySdk.xcframework` | OpenTelemetry SDK |
| `CiscoLogger.xcframework` | Logging infrastructure |
| `CiscoDiskStorage.xcframework` | Persistent storage |
| `CiscoEncryption.xcframework` | Data encryption |

### Optional Instrumentation Frameworks

Add these based on which instrumentation you need:

| Framework | What it tracks |
|-----------|---------------|
| `SplunkNavigation.xcframework` | Screen view changes |
| `SplunkNetwork.xcframework` | HTTP requests via URLSession |
| `SplunkNetworkMonitor.xcframework` | Network connectivity status |
| `SplunkCrashReports.xcframework` | Crash report instrumentation (+ `SplunkCrashReporter.xcframework`) |
| `SplunkInteractions.xcframework` | UI taps and gestures |
| `SplunkAppStart.xcframework` | App launch timing |
| `SplunkAppState.xcframework` | Foreground/background transitions |
| `SplunkWebView.xcframework` | WKWebView bridge |
| `SplunkSlowFrameDetector.xcframework` | Slow/frozen frame detection |
| `SplunkCustomTracking.xcframework` | Custom events and workflows |
| `SplunkSessionReplayProxy.xcframework` | Session Replay (+ all `Cisco*.xcframework`) |

### Objective-C Support

For Objective-C projects, also include `SplunkAgentObjC.xcframework` and use the `SPLKSplunkRum` class.

### visionOS Note

`SplunkCrashReporter.xcframework` and `SplunkCrashReports.xcframework` do **not** support visionOS. Crash reporting is automatically disabled on that platform. All other modules work on visionOS.

---

## Development

### Prerequisites

- Xcode 16+
- [Tuist](https://tuist.io) (`brew install tuist`)
- macOS 14+

### Cleaning

```bash
make clean    # Removes all build artifacts, vendored sources, and generated projects
```

### Incremental Builds

The build system caches archives. To rebuild a specific module, remove its archives:

```bash
rm -rf build/agent/archives/SplunkAgent-*
make build-agent
```
