# XCFramework Build System

Build tooling for producing signed, multi-platform xcframeworks from the Splunk RUM iOS SDK source.

## Quick Start

```bash
# Full build: OTel + PLCrash + Cisco static inputs + SplunkAgent
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
| 4 | `make build-agent` | Generates the main Tuist workspace and builds `SplunkAgent.xcframework` plus `SplunkAgentObjC.xcframework` |

### Output

All built xcframeworks are placed in `output/xcframeworks/`:

```
output/xcframeworks/
├── OpenTelemetryApi.xcframework
├── OpenTelemetrySdk.xcframework
├── CrashReporter.xcframework
├── SplunkAgent.xcframework
└── SplunkAgentObjC.xcframework
```

Cisco Session Replay xcframeworks are downloaded into `dependencies/` and linked statically into `SplunkAgent.xcframework`. They are not shipped as standalone artifacts.

### Platform Matrix

| Module | iOS | tvOS | visionOS | macCatalyst |
|--------|-----|------|----------|-------------|
| SplunkAgent / SplunkAgentObjC | arm64 | arm64 | arm64 | arm64 |
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

## Release

Releasing xcframeworks is a two-part process: CI builds the unsigned artifacts, then a developer signs them locally and uploads to the GitHub release.

### How it works

1. A developer triggers `release.yml` with a version and ticket ID.
2. The release PR is reviewed and merged to `main`.
3. `merge_release.yml` runs automatically — creates a git tag and a GitHub Release.
4. `build-xcframeworks.yml` triggers on the release event, builds the five shipped xcframeworks, validates them, runs a clean consumer smoke test, and uploads an **unsigned** artifact.
5. A developer downloads the unsigned artifact, signs locally, and uploads the signed zip to the release.

> **Note:** Automated CI signing (Job 2 in `build-xcframeworks.yml`) is temporarily disabled because distribution certificates cannot be stored in GitHub secrets. The implementation is preserved and can be re-enabled by setting the `SIGNING_ENABLED` repository variable to `"true"`.

### Local signing

After CI finishes the build (step 4 above), run the convenience script:

```bash
# Signs and uploads to the release in one step
./scripts/sign-and-upload.sh 1.2.0
```

The script will:
- Auto-detect your signing identity from the local keychain
- Download the unsigned artifact from the latest CI run
- Sign all shipped xcframeworks
- Validate signatures for all shipped xcframeworks
- Package and upload the zip to the existing GitHub release

#### Options

```bash
# Use a specific CI run
./scripts/sign-and-upload.sh 1.2.0 --run-id 12345678

# Use a specific signing identity
./scripts/sign-and-upload.sh 1.2.0 --identity "Apple Distribution: Splunk Inc. (TEAMID)"

# Sign and package without uploading (dry run)
./scripts/sign-and-upload.sh 1.2.0 --skip-upload
```

#### Prerequisites

- Apple distribution certificate installed in your local keychain
- `gh` CLI installed and authenticated (`brew install gh && gh auth login`)

### Fully local build and package

To bypass GitHub Actions, run the same stages locally:

```bash
make build
make validate
make smoke-test
make sign SIGNING_IDENTITY="Apple Distribution: Splunk Inc. (TEAMID)"
make validate RELEASE=true
./scripts/release.sh 1.2.0
```

The resulting zip is written to `output/SplunkAgent-XCFrameworks-1.2.0.zip` and can be uploaded to a GitHub Release manually.

### Manual step-by-step (alternative)

If you prefer to run each step individually:

```bash
# 1. Find the CI run ID
gh run list --workflow=build-xcframeworks.yml --limit 1

# 2. Download the unsigned artifact
gh run download <RUN_ID> -n splunk-agent-xcframeworks-unsigned -D tools/xcframework/output/xcframeworks/

# 3. Find your signing identity
security find-identity -v -p codesigning

# 4. Sign shipped xcframeworks
./scripts/sign-xcframeworks.sh "Apple Distribution: Splunk Inc. (TEAMID)"

# 5. Validate all signatures
RELEASE=true ./scripts/validate-xcframeworks.sh

# 6. Package and upload to the existing release
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

Swift applications need these frameworks:

| Framework | Purpose |
|-----------|---------|
| `SplunkAgent.xcframework` | Main SDK and public API with Splunk and Cisco modules statically linked |
| `OpenTelemetryApi.xcframework` | OpenTelemetry API |
| `OpenTelemetrySdk.xcframework` | OpenTelemetry SDK |
| `CrashReporter.xcframework` | Crash reporter dependency for non-visionOS targets |

Do not add internal `Splunk*.xcframework` module artifacts or `Cisco*.xcframework` artifacts to binary customer applications.

### Objective-C Support

For Objective-C projects, also include `SplunkAgentObjC.xcframework` and use the `SPLKSplunkRum` class.

### visionOS Note

`CrashReporter.xcframework` does **not** support visionOS. Do not link it into visionOS applications; crash reporting is automatically unavailable on that platform.

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
