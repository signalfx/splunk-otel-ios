# XCFramework Build System

Build tooling for producing signed, multi-platform xcframeworks from the Splunk RUM iOS SDK source.

## Quick Start

```bash
# Full build: OTel + PLCrash + Cisco download + Agent modules
make build

# Validate all built xcframeworks
make validate

# Build & link a smoke test app
make smoke-test
```

## Build Pipeline

The `make build` target runs four stages in order:

| Stage | Command | What it does |
|-------|---------|-------------|
| 1 | `make build-otel` | Clones `opentelemetry-swift-core`, generates a Tuist project, and archives `OpenTelemetryApi` + `OpenTelemetrySdk` for all 7 platform slices |
| 2 | `make build-plcrash` | Clones `PLCrashReporter`, builds it as a **dynamic** framework from source for iOS/tvOS/macCatalyst |
| 3 | `make populate-deps` | Symlinks OTel + PLCrash outputs into `dependencies/`, downloads Cisco Session Replay xcframeworks from S3 |
| 4 | `make build-agent` | Generates the main Tuist workspace and builds all 16 Splunk module xcframeworks |

### Output

All built xcframeworks are placed in `output/xcframeworks/`:

```
output/xcframeworks/
├── OpenTelemetryApi.xcframework
├── OpenTelemetrySdk.xcframework
├── CrashReporter.xcframework
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

Cisco Session Replay xcframeworks are downloaded into `dependencies/` and are **not** rebuilt (they are pre-built by the Session Replay team).

### Platform Matrix

| Module | iOS | tvOS | visionOS | macCatalyst |
|--------|-----|------|----------|-------------|
| Most modules | arm64 | arm64 | arm64 | arm64 |
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
| `CISCO_XCFRAMEWORKS_PATH` | *(empty)* | Local path to Cisco xcframeworks (downloads from S3 if unset) |

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
