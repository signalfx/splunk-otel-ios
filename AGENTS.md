# Splunk RUM Agent for iOS - AI Assistant Context

This document provides context for AI assistants working on this codebase.

## Project Overview

**Splunk RUM Agent for iOS** is a modular Swift Package for Real User Monitoring (RUM). It instruments iOS, iPadOS, tvOS, visionOS, and macCatalyst applications to collect telemetry data (traces, spans, logs) and sends it to Splunk Observability Cloud.

- **Language**: Swift 5.9+
- **Package Manager**: Swift Package Manager (SPM)
- **Minimum iOS**: 13.0
- **Core Dependency**: [OpenTelemetry Swift Core](https://github.com/open-telemetry/opentelemetry-swift-core) (API and SDK only, no exporters)

## Architecture

### Module System

The SDK uses a modular architecture where each instrumentation type is a separate SPM target. All modules conform to the `Module` protocol defined in `SplunkCommon`.

**Core Modules:**
- `SplunkAgent` - Main agent and public API
- `SplunkAgentObjC` - Objective-C bridging layer
- `SplunkCommon` - Shared utilities and protocols

**Instrumentation Modules:**
- `SplunkAppStart` - App startup time tracking
- `SplunkAppState` - App lifecycle events (foreground/background)
- `SplunkCrashReports` - Crash reporting via PLCrashReporter
- `SplunkCustomTracking` - Custom events and workflows
- `SplunkInteractions` - UI interaction tracking
- `SplunkNavigation` - Screen navigation tracking
- `SplunkNetwork` - URLSession instrumentation
- `SplunkNetworkMonitor` - Network status monitoring
- `SplunkSlowFrameDetector` - Slow/frozen frame detection
- `SplunkWebView` - WKWebView instrumentation
- `SplunkSessionReplayProxy` - Session replay proxy

**Infrastructure Modules:**
- `SplunkOpenTelemetry` - OTel integration, span/log processors, and attribute handling
- `SplunkOpenTelemetryBackgroundExporter` - Custom OTLP/JSON exporters for traces, logs, and metrics with background task support

### Module Protocol Pattern

All modules implement this pattern:

```swift
public protocol Module {
    associatedtype Configuration: ModuleConfiguration
    associatedtype RemoteConfiguration: RemoteModuleConfiguration
    associatedtype EventMetadata: ModuleEventMetadata
    associatedtype EventData: ModuleEventData

    init()
    func install(with: ModuleConfiguration?, remoteConfiguration: RemoteModuleConfiguration?)
    func onPublish(data: @escaping (EventMetadata, EventData) -> Void)
    func deleteData(for: any ModuleEventMetadata)
}
```

## Directory Structure

```
Splunk<ModuleName>/
├── Sources/
│   └── Splunk<ModuleName>/
│       ├── Model/                    # Data models
│       ├── Module/                   # Module protocol conformance
│       │   ├── <Module>+Module.swift
│       │   ├── <Module>Configuration.swift
│       │   └── <Module>RemoteConfiguration.swift
│       └── <ModuleName>.swift        # Main implementation
└── Tests/
    └── Splunk<ModuleName>Tests/
        ├── Testing Support/
        │   ├── Builders/             # Test builders
        │   └── Mocks/                # Mock objects
        └── <ModuleName>Tests.swift
```

## Code Style

### File Organization

- Use `// MARK: -` for major sections, `// MARK:` for subsections
- Order sections: Types → Static Constants → Constants → Private → Public → Initialization → Methods
- Protocol conformances go in separate extensions

### Naming Conventions

- Files: `PascalCase`, extensions use `+` (e.g., `UIView+RoundedColors.swift`)
- Types/Protocols: `UpperCamelCase`
- Variables/Functions: `lowerCamelCase`
- No abbreviations except common ones (API, URL)

### Swift Style

- Use `guard` over `if` when possible, with `return` on separate line
- Multi-line guards: each condition on separate line under `guard` keyword
- 4-space indentation, max 160 character line width
- Trailing commas: never
- SwiftFormat and SwiftLint are used for enforcement

### Documentation

- Use DocC (`///`) for all protocols and public API
- DocC comments end with a period
- Inline comments (`//`) for implementation details, no period for short comments
- Format DocC parameters properly with blank lines between sections

## Testing Patterns

### Test Builders

Use the builder pattern for test setup. Builders are located in `Testing Support/Builders/`:

```swift
final class AgentTestBuilder {
    static func buildDefault() throws -> SplunkRum {
        let configuration = try ConfigurationTestBuilder.buildDefault()
        return try build(with: configuration)
    }

    static func build(with configuration: AgentConfiguration, ...) throws -> SplunkRum {
        // Setup code
    }
}
```

### Test Naming

- Test files: `<ClassName>Tests.swift`
- Test methods: `test<Behavior>()` or `test<Condition>_<Expected>()`

## Build Commands

```bash
# Build for iOS Simulator
xcodebuild build -scheme SplunkAgent -destination "OS=26.2,name=iPhone 17"

# Run unit tests
xcodebuild -scheme SplunkAgent -destination "OS=26.2,name=iPhone 17" test

# Install SwiftLint
brew install swiftlint
```

## Environment Variables

| Variable | Description |
|----------|-------------|
| `USE_SESSION_REPLAY_REPO` | Use repository-based SR dependencies (default: false) |
| `USE_LOCAL_SESSION_REPLAY` | Use local path for SR (default: false) |
| `SESSION_REPLAY_BRANCH` | Git branch for remote SR dependency (default: "develop") |
| `SESSION_REPLAY_LOCAL_PATH` | Local path to SR repo (default: "../../smartlook-ios-sdk-private") |
| `USE_DEVELOPMENT_PLUGINS` | Enable linter/formatter plugins (default: false) |

## Key Files

| File | Purpose |
|------|---------|
| `Package.swift` | SPM manifest with all targets and dependencies |
| `SplunkAgent/Sources/SplunkAgent/Public API/` | Public API surface |
| `SplunkCommon/Sources/SplunkCommon/Modules/Module.swift` | Core Module protocol |
| `SplunkOpenTelemetryBackgroundExporter/.../OTLPEncoder/` | Custom OTLP/JSON encoder |
| `SplunkOpenTelemetryBackgroundExporter/.../OTLPVersion.swift` | OTLP spec version tracking |
| `.swiftformat` | SwiftFormat configuration |
| `CODESTYLE.md` | Detailed code style guide |
| `Development.md` | Build and test instructions |
| `CONTRIBUTING.md` | Contribution guidelines |

## Common Tasks

### Adding a New Module

1. Create `Splunk<ModuleName>/` directory with `Sources/` and `Tests/` subdirectories
2. Implement the `Module` protocol in `<ModuleName>+Module.swift`
3. Create configuration types implementing `ModuleConfiguration` and `RemoteModuleConfiguration`
4. Add target to `Package.swift` in `generateMainTargets()`
5. Add test target with builders and mocks

### Adding a Public API Method

1. Add to appropriate file in `SplunkAgent/Sources/SplunkAgent/Public API/`
2. Add Objective-C bridge in `SplunkAgentObjC` if needed
3. Document with DocC
4. Add unit tests

## Dependencies

- **opentelemetry-swift-core**: OpenTelemetry API and SDK (no protocol exporters - we use custom OTLP/JSON implementation)
- **PLCrashReporter**: Crash reporting
- **Cisco Binary Targets**: Session replay (via wrapper targets)

## OTLP/JSON Encoder Architecture

The SDK uses a custom OTLP/JSON encoder instead of the upstream `OpenTelemetryProtocolExporter` to reduce binary size. The implementation is located in `SplunkOpenTelemetryBackgroundExporter/Sources/.../OTLPEncoder/`.

### Structure

```
OTLPEncoder/
├── Adapters/                    # Convert OTel SDK types to OTLP models
│   ├── LogRecordAdapter.swift   # ReadableLogRecord → OTLPLogRecord
│   ├── MetricDataAdapter.swift  # MetricData → OTLPMetric
│   ├── SpanDataAdapter.swift    # SpanData → OTLPSpan
│   └── SplunkLogRecordAdapter.swift  # Binary data support for Session Replay
├── EncodingWrappers/            # Custom Encodable wrappers for OTLP types
│   ├── OTLPInt64.swift          # Encodes Int64 as decimal string
│   ├── OTLPUInt64.swift         # Encodes UInt64 as decimal string
│   ├── OTLPTraceId.swift        # Encodes as 32-char lowercase hex
│   └── OTLPSpanId.swift         # Encodes as 16-char lowercase hex
├── Models/                      # OTLP JSON data structures
│   ├── Common/                  # Shared types (Resource, KeyValue, AnyValue)
│   ├── Logs/                    # Log-specific models
│   ├── Metrics/                 # Metric-specific models (Gauge, Sum, Histogram, etc.)
│   └── Trace/                   # Span-specific models
└── OTLPVersion.swift            # OTLP specification version tracking
```

### Key Design Decisions

1. **JSON Encoding**: Uses Swift's `Encodable` with custom `encode(to:)` for OTLP-compliant JSON
2. **String-encoded integers**: Large integers (timestamps, IDs) encoded as strings per OTLP spec
3. **Base64 binary data**: `bytesValue` in `OTLPAnyValue` encodes binary data as base64
4. **Null omission**: Optional fields with nil values are omitted from JSON output
5. **Version tracking**: `OTLPVersion.swift` documents the OTLP specification version for maintenance

## License

Apache License 2.0. All source files must include the Splunk copyright header:

```swift
//
/*
Copyright 2026 Splunk Inc.

Licensed under the Apache License, Version 2.0 (the "License");
...
*/
```
