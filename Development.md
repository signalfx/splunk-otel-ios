# Building, testing, and contributing to this project

## Dependencies

This project is a Swift Package and manages most of its dependencies via the `Package.swift` manifest. The core dependency is [OpenTelemetry Swift](https://github.com/open-telemetry/opentelemetry-swift), which provides the foundation for tracing.

Some dependencies, such as Session Replay, are included as pre-compiled binaries. A reference list of major dependencies can also be found in `dependencies.txt`.

## Building and Testing

The recommended way to work on this project is to open the `Package.swift` file in Xcode. This will resolve all package dependencies and set up the project for development.

Once the project is open, select the **`SplunkAgent`** scheme. From there, you can choose a target to run, such as one of the demo applications (e.g., `AgentTestApp`), or run the test suite for the library.

### Command Line

To build from the command line, you must use `xcodebuild`. The `xcodebuild -list` command confirms that `SplunkAgent` is the correct scheme to use.

To build the scheme for a simulated iOS device:
```bash
xcodebuild build -scheme SplunkAgent -destination 'generic/platform=iOS Simulator'
```

To run the unit tests:
```bash
xcodebuild test -scheme SplunkAgent -destination 'generic/platform=iOS Simulator'
```

### Linting

This project uses SwiftLint to enforce code style. It is recommended to install it to ensure your contributions match the project's standards.
```bash
brew install swiftlint
```

## Contributing

See [the CONTRIBUTING document](./CONTRIBUTING.md) for details on our contribution process, including how to submit pull requests.  

