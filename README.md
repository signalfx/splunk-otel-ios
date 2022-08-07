>ℹ️&nbsp;&nbsp;SignalFx was acquired by Splunk in October 2019. See [Splunk SignalFx](https://www.splunk.com/en_us/investor-relations/acquisitions/signalfx.html) for more information.

# Splunk OpenTelemetry iOS agent

The Splunk RUM iOS agent provides a swift package
that can be added to an app that captures:

- HTTP requests, via `URLSession` instrumentation
- Application startup information
- UI activity - screen name (typically ViewController name), actions, and PresentationTransitions
- Crashes/unhandled exceptions via [SplunkRumCrashReporting](https://github.com/signalfx/splunk-otel-ios-crashreporting)

> :construction: This project is currently in **BETA**. It is **officially supported** by Splunk. However, breaking changes **MAY** be introduced.

## Getting Started

To get started, import the package into your app, either through the Xcode menu
(`File -> Swift Packages -> Add Package Dependency` or `File -> Add Packages`) or through your `Package.swift`:

```swift
.package(url: "https://github.com/signalfx/splunk-otel-ios/", from: "0.4.0");
...
.target(name: "MyAwesomeApp", dependencies: ["SplunkOtel"]),
```

You'll then need to initialize the library with the appropriate configuration parameters.  The best place to do
this is probably your `AppDelegate`'s `...didFinishLaunchingWithOptions:` method:

```swift
// Swift example
import SplunkOtel
...
// Your beaconUrl and rumAuth will be provided by your friendly Splunk representative
SplunkRum.initialize(beaconUrl: "https://rum-ingest.us0.signalfx.com/v1/rum", rumAuth: "ABCD...")
```

or

```objectivec
// Objective-C example
@import SplunkOtel;
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
| environment | String? | Value for environment global attribute | `nil` |
| ignoreURLs | NSRegularExpression? | Regex of URLs to ignore when reporting HTTP activity | `nil` |
| spanFilter | ((SpanData) -> SpanData?)? | Closure to modify or reject/ignore spans.  See example below.  | `nil` |
| showVCInstrumentation | Bool | Enable span creation for ViewController Show events (not applicable to all UI frameworks/apps) | true |
| screenNameSpans | Bool | Enable span creation for changes to the screen name | true |
| networkInstrumentation | Bool | Enable span creation for network activities | true |
| enableDiskCache | Bool | Enable disk caching of exported spans. All spans will be written to disk and deleted on a successful export. | false |
| spanDiskCacheMaxSize | Int64 | Threshold in bytes from which spans will start to be dropped from the disk cache (oldest first). Only applicable when disk caching is enabled. | 25 MB |
| slowFrameDetectionThresholdMs | Double? | The slow frame threshold counts the frames that took more than the specified amount of milliseconds as slow and reports it as a span. Counting is done in 1 second buckets. | 16.7 ms |
| frozenFrameDetectionThresholdMs | Double? | The frozen frame threshold counts the frames that took more than the specified milliseconds as frozen and reports it as a span. Counting is done in 1 second buckets. | 700 ms |
| enableDiskCache | Bool | Enable disk caching of exported spans. All spans will be written to disk and deleted on a successful export. The storage is capped at 64 MB. | false |


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

### Span Filtering

You can modify or reject spans with a `spanFilter` function (only supported in Swift, not Objective-C):

```swift
options.spanFilter = { spanData in
  var spanData = spanData
  if spanData.name == "DropThis" {
    return nil // spans with this name will not be sent
  }
  var atts = spanData.attributes
  atts["http.url"] = .string("redacted") // change values for all urls
  return spanData.settingAttributes(atts)
}
```

## Integrate with Splunk Browser RUM

Mobile RUM instrumentation and Browser RUM instrumentation can be used simultaneously 
by sharing the `splunk.rumSessionId` between the native/iOS instrumentation and the 
browser/web instrumentation. This allows you to see data from both your native app 
and your web app combined in one stream.

### Requirements

- Your iOS app has at least one [WebKit `WKWebView`](https://developer.apple.com/documentation/webkit/wkwebview) object.
- The website loaded in the WebView is instrumented using [Splunk Browser RUM](https://github.com/signalfx/splunk-otel-js-web).

### Example

See the following Swift snippet for an example of how to integrate with Splunk Browser RUM:

```swift
import WebKit
import SplunkOtel

...
  /* 
Make sure that the WebView instance only loads pages under 
your control and instrumented with Splunk Browser RUM. The 
integrateWithBrowserRum() method can expose the splunk.rumSessionId
of your user to every site/page loaded in the WebView instance.
*/
  let webview: WKWebView = ...
  SplunkRum.integrateWithBrowserRum(webview)
```

> :warning: **Warning**: Make sure that the WebView instance only loads pages under 
your control and instrumented with Splunk Browser RUM. Calling 
`SplunkRum.integrateWithBrowserRum()` exposes your user's `splunk.rumSessionId` 
to every site/page loaded in the WebView instance.
## Version information

- This library is compatible with iOS 11 and up (and iPadOS 13 and up)
- This library incorporates [opentelemetry-swift](https://github.com/open-telemetry/opentelemetry-swift) v1.0.2

## Building and contributing

Please read [CONTRIBUTING.md](./CONTRIBUTING.md) for instructions on building, running tests, and so forth.

## License

This library is released under the terms of the Apache Softare License version 2.0.
See [the license file](./LICENSE) for more details.
