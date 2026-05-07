# XCFramework Build System

Build tooling for producing signed, multi-platform xcframeworks from the Splunk RUM iOS SDK source.

## Quick Start

```bash
# Full build: OTel + PLCrash + dynamic Cisco + Agent modules
export SESSION_REPLAY_LOCAL_PATH=/path/to/session-replay-repo
make build

# Validate all built xcframeworks
make validate

# Build & link a smoke test app
make smoke-test
```

## Build Pipeline

The `make build` target requires `SESSION_REPLAY_LOCAL_PATH` and runs five stages in order:

| Stage | Command | What it does |
|-------|---------|-------------|
| 1 | `make build-otel` | Clones `opentelemetry-swift-core`, generates a Tuist project, and archives `OpenTelemetryApi` + `OpenTelemetrySdk` for all 7 platform slices |
| 2 | `make build-plcrash` | Clones `PLCrashReporter`, builds it as a **dynamic** framework from source for iOS/tvOS/macCatalyst |
| 3 | `make build-cisco` | Builds the 9 Cisco Session Replay frameworks as **dynamic** xcframeworks from the local Session Replay checkout |
| 4 | `make populate-deps` | Stages OTel, PLCrash, and already-built dynamic Cisco xcframeworks into `dependencies/` |
| 5 | `make build-agent` | Generates the main Tuist workspace and builds all 16 Splunk module xcframeworks |

### Output

All built xcframeworks are placed in `output/xcframeworks/`:

```
output/xcframeworks/
├── OpenTelemetryApi.xcframework
├── OpenTelemetrySdk.xcframework
├── CrashReporter.xcframework
├── CiscoCommon.xcframework
├── CiscoLogger.xcframework
├── CiscoEncryption.xcframework
├── CiscoSwizzling.xcframework
├── CiscoInteractions.xcframework
├── CiscoDiskStorage.xcframework
├── CiscoSessionReplay.xcframework
├── CiscoInstanceManager.xcframework
├── CiscoRuntimeCache.xcframework
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

Cisco Session Replay xcframeworks are built locally as dynamic frameworks. The Agent `Package.swift` Cisco binary target URLs intentionally point to static artifacts for SPM and are not used by this xcframework release path.

### Platform Matrix

| Module | iOS | tvOS | visionOS | macCatalyst |
|--------|-----|------|----------|-------------|
| Splunk modules | arm64 | arm64 | arm64 | arm64 |
| Cisco modules | arm64 | arm64 | arm64 | arm64+x86_64 |
| SplunkCrashReports | arm64 | arm64 | -- | arm64 |
| OpenTelemetryApi/Sdk | arm64 | arm64 | arm64 | arm64+x86_64 |
| CrashReporter | arm64 | arm64 | -- | arm64+x86_64 |

All platforms also include simulator slices (arm64+x86_64).

macCatalyst slices for agent modules are arm64-only to match Cisco Session Replay xcframeworks.

### Configuration

Key variables in the Makefile:

| Variable | Default | Description |
|----------|---------|-------------|
| `OTEL_VERSION` | `2.3.0` | OpenTelemetry Swift Core tag to build |
| `PLCRASH_VERSION` | `1.12.0` | PLCrashReporter tag to build |
| `SESSION_REPLAY_LOCAL_PATH` | *(required)* | Local path to the Session Replay repository |
| `CISCO_XCFRAMEWORKS_PATH` | *(empty)* | Legacy path to prebuilt dynamic Cisco xcframeworks |

---

## Release

Releasing xcframeworks is currently a local process while the Agent and Session Replay repositories are separate. The local release script builds dynamic Cisco frameworks from `SESSION_REPLAY_LOCAL_PATH`, signs all 28 xcframeworks, validates, packages, and optionally uploads to the GitHub release.

### How it works

1. A developer triggers `release.yml` with a version and ticket ID.
2. The release PR is reviewed and merged to `main`.
3. `merge_release.yml` runs automatically — creates a git tag and a GitHub Release.
4. A developer runs `scripts/sign-and-upload.sh` locally with `SESSION_REPLAY_LOCAL_PATH` set.
5. The script builds, signs, validates, packages, and uploads `SplunkAgent-XCFrameworks-<version>.zip`.

`build-xcframeworks.yml` is now a manual legacy/testing workflow. It requires caller-provided dynamic Cisco artifacts and must not download Cisco artifacts from Agent `Package.swift`.

### Local signing

Run the convenience script from `tools/xcframework`:

```bash
# Signs and uploads to the release in one step
export SESSION_REPLAY_LOCAL_PATH=/path/to/session-replay-repo
./scripts/sign-and-upload.sh 1.2.0
```

The script will:
- Auto-detect your signing identity from the local keychain
- Build OTel, PLCrashReporter, dynamic Cisco, and Splunk xcframeworks locally
- Record the Session Replay commit, branch, and dirty state in `cisco-release-manifest.txt`
- Sign all 28 xcframeworks, including Cisco frameworks
- Validate signatures for all shipped xcframeworks
- Package and upload the zip to the existing GitHub release

#### Options

```bash
# Legacy: use a specific CI run with already-dynamic Cisco artifacts
./scripts/sign-and-upload.sh 1.2.0 --run-id 12345678

# Use a specific signing identity
./scripts/sign-and-upload.sh 1.2.0 --identity "Apple Distribution: Splunk Inc. (TEAMID)"

# Sign and package without uploading (dry run)
export SESSION_REPLAY_LOCAL_PATH=/path/to/session-replay-repo
./scripts/sign-and-upload.sh 1.2.0 --skip-upload
```

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

# 3. Sign all shipped xcframeworks, including Cisco
./scripts/sign-xcframeworks.sh --include-cisco "Apple Distribution: Splunk Inc. (TEAMID)"

# 4. Validate all signatures
RELEASE=true ./scripts/validate-xcframeworks.sh

# 5. Package and upload to the existing release
./scripts/release.sh 1.2.0 --upload-to 1.2.0
```

---

## Customer Integration Guide

### Adding XCFrameworks to Your Xcode Project

1. **Download** the release `.zip` and extract it. You will have a folder containing all `.xcframework` bundles.

2. **Drag and drop** all `.xcframework` bundles into your Xcode project navigator.

3. For each target that uses Splunk RUM, go to **General > Frameworks, Libraries, and Embedded Content** and ensure every framework is set to **Embed & Sign**.

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
| `SplunkCrashReports.xcframework` | Crash reports (+ `CrashReporter.xcframework`) |
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

`SplunkCrashReports.xcframework` and `CrashReporter.xcframework` do **not** support visionOS. Crash reporting is automatically disabled on that platform. All other modules work on visionOS.

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
