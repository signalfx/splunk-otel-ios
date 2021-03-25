# Splunk OpenTelemetry iOS agent

The Splunk RUM iOS agent provides a swift package
that can be added to an app that captures:

- Crashes/unhandled exceptions via [PLCrashReporter](https://github.com/microsoft/plcrashreporter)
- HTTP requests, via `URLSession` instrumentation
- Application startup information
- FIXME others as added

## Getting Started

To get started, import the package into your app, either through the Xcode menu
`File -> Swift Packages -> Add Package Dependency` or through your `Package.swift`:

```swift
.package(url: "https://github.com/signalfx/splunk-otel-ios/", from: "0.1");
...
.target(name: "MyAwesomeApp", dependencies: ["SplunkRum"]),
```

You'll then need to initialize the library with the appropriate configuration parameters.

```swift
import SplunkRum
...
// Your beaconUrl and rumAuth will be provided by your friendly Splunk representative
SplunkRum.initialize(beaconUrl: "https://rum-ingest.us0.signalfx.com/v1/rum", rumAuth: "ABCD...")
```

or

```objectivec
@import SplunkRum;
...
// Your beaconUrl and rumAuth will be provided by your friendly Splunk representative
[SplunkRum initializeWithBeaconUrl: @"https://rum-ingest.us0.signalfx.com/v1/rum" rumAuth: @"ABCD..." options: nil];
```

## Installation options

| Option | Type | Notes | Default |
|--------|------|-------|---------|
| beaconUrl | String (required) | Destination for captured data | (No default)
| rumAuth | String (required) | Publicly-visible `rumAuth` value.  Please do not paste any other access token or auth value into here, as this will be visible to every user of your app | (No default) |
| debug | Bool | Turns on/off internal debug logging | false |
| allowInsecureBeacon | Bool | Allows http beacon urls | false |
| globalAttributes | [String: Any] | Extra attributes to add to each reported span.  See also `setGlobalAttributes` | [:] |

## Manual OpenTelemetry instrumentation

### Tracing API

You can use the OpenTelemetry Swift APIs to report interesting things in your app.  For example, if you had a `calculateTax`
function you wanted to time:

```swift
func calculateTax() {
  let tracer = OpenTelemetrySDK.instance.tracerProvider.get(instrumentationName: "MyApp")
  let span = tracer.spanBuilder(spanName: "calculateTax").startSpan()
  span.setAttribute(key: "numClaims", value: claims.count)
  ...
  ...
  span.end() // or use defer for this
}
```

## Version information

- This library works on iOS 11 and up
- This library incorporates [opentelemetry-swift](https://github.com/open-telemetry/opentelemetry-swift) v0.6

## Building and contributing

Please read [CONTRIBUTING.md](./CONTRIBUTING.md) for instructions on building, running tests, and so forth.

## License

This library is released under the terms of the Apache Softare License version 2.0.
See [the license file](./LICENSE) for more details.
