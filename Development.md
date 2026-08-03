# Building, testing, and contributing to this project

## Dependencies

This project is a Swift Package and manages most of its dependencies via the `Package.swift` manifest. The core dependency is [OpenTelemetry Swift Core](https://github.com/open-telemetry/opentelemetry-swift-core), which provides the API and SDK foundations for telemetry. Protocol exporters are intentionally not used; this project ships a custom OTLP/JSON exporter to control binary size.

Some dependencies, such as Session Replay, are included as pre-compiled binaries. A reference list of major dependencies can also be found in `dependencies.txt`.

Crash reporting uses the vendored, symbol-prefixed `SplunkCrashReporter` target rather than a remote PLCrashReporter package dependency. Keep its source target synchronized with the xcframework manifest when updating it.

### Session Replay Dependency Mode

Session Replay uses binary dependencies by default. For development, the dependency source can be changed with these environment variables:

| Variable | Description |
|----------|-------------|
| `USE_SESSION_REPLAY_REPO` | Use repository-based Session Replay dependencies. |
| `USE_LOCAL_SESSION_REPLAY` | Use a local Session Replay checkout. |
| `SESSION_REPLAY_BRANCH` | Git branch for repository-based Session Replay dependencies. |
| `SESSION_REPLAY_LOCAL_PATH` | Local path to the Session Replay checkout. |
| `USE_DEVELOPMENT_PLUGINS` | Enable development-only linting/formatting plugins. |

## Building and Testing

The recommended way to work on this project is to open the `Package.swift` file in Xcode. This will resolve all package dependencies and set up the project for development.

Once the project is open, select the **`SplunkAgent`** scheme. From there, you can choose a target to run, such as one of the demo applications (e.g., `AgentTestApp`), or run the test suite for the library.

### Command Line

To build from the command line, you must use `xcodebuild`. The `xcodebuild -list` command confirms that `SplunkAgent` is the correct scheme to use.

To build the scheme for a simulated iOS device:
```bash
xcodebuild build -scheme SplunkAgent -destination 'generic/platform=iOS Simulator'
```

To run the unit tests (example; your Simulator version may vary):
```bash
xcodebuild test -scheme SplunkAgent -destination 'platform=iOS Simulator,name=iPhone 16'
```

### Linting

This project uses SwiftLint to enforce code style. It is recommended to install it to ensure your contributions match the project's standards.
```bash
brew install swiftlint
```

## Binary Distribution

The Swift Package and xcframework distribution have separate manifests. When changing targets, products, supported platforms, dependencies, or resources in `Package.swift`, update `tools/xcframework/Project.swift` as well and run:

```bash
tools/xcframework/scripts/check-manifest-sync.sh
```

The dSYM upload helper is documented separately in `dsymUploader/README.md`.

## Contributing

See [the CONTRIBUTING document](./CONTRIBUTING.md) for details on our contribution process, including how to submit pull requests.
