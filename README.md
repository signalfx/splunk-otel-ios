# Splunk OpenTelemetry iOS agent

The Splunk RUM iOS agent provides a swift package
that can be added to an app that captures:

- HTTP requests, via `URLSession` instrumentation
- Application startup information
- UI activity - screen name (typically ViewController name), actions, and PresentationTransitions
- Crashes/unhandled exceptions via [SplunkRumCrashReporting](https://github.com/signalfx/splunk-otel-ios-crashreporting)

> :construction: This project is currently in **BETA**.

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
// Swift example
import SplunkRum
...
// Your beaconUrl and rumAuth will be provided by your friendly Splunk representative
SplunkRum.initialize(beaconUrl: "https://rum-ingest.us0.signalfx.com/v1/rum", rumAuth: "ABCD...")
```

or

```objectivec
// Objective-C example
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
| environment | String? (optional) | Value for environment global attribute | `nil` |

## Crash Reporting

Crash reporting is provided via an optional package called
[SplunkRumCrashReporting](https://github.com/signalfx/splunk-otel-ios-crashreporting).  Follow
the instructions at that link to enable this feature.

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

### Manual Error Reporting

You can report handled errors/exceptions/messages with a convenience API:

```swift
SplunkRum.reportError(oops)
```

There are `reportError` overloads for `String`, `Error`, and `NSException`.

### Managing Global Attributes

Global attributes are key/value pairs added to all reported data.  This is useful for reporting app- or user-specfic
values as tags.  For example, you might add `accountType={gold,silver,bronze}` to every span (piece of data) reported
by the Splunk RUM library.  You can specify global attributes in the during `SplunkRum.initialize()` as `options.globalAttributes` or use
`SplunkRum.setGlobalAttributes / SplunkRum.removeGlobalAttribute` at any point during your app's execution.

### Manually changing screen names

You can set `screen.name` manually with a simple line of code:

```swift
SplunkRum.setScreenName("AccountSettingsTab")
```

This name will hold until your next call to `setScreenName`.  **NOTE**: using `setScreenName` once
disables automatic screen name instrumentation, to avoid overwriting your chosen name(s).  If you
instrument your application to `setScreenName`, please do it everywhere.

## Version information

- This library is compatible with iOS 11 and up (and iPadOS 13 and up)
- This library incorporates [opentelemetry-swift](https://github.com/open-telemetry/opentelemetry-swift) v1.0.2

## Building and contributing

Please read [CONTRIBUTING.md](./CONTRIBUTING.md) for instructions on building, running tests, and so forth.

## License

This library is released under the terms of the Apache Softare License version 2.0.
See [the license file](./LICENSE) for more details.
