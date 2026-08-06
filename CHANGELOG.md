# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

* Added `customTracking.trackError(typeName:message:stacktrace:attributes:)` for reporting an error with an explicitly supplied stacktrace. Unlike the existing `trackError` overloads, the supplied stack is emitted verbatim as `exception.stacktrace` (no native stack is derived) and the resulting `component=error` span is named after `typeName` (falling back to `"error"`). This is the native emission path for caught JavaScript/Dart errors bridged from the React Native and Flutter agents. A matching Objective-C selector (`trackErrorWithType:message:stacktrace:attributes:`) is also available.
* Added an internal AppStart lifecycle snapshot API that lets hybrid agents provide early lifecycle timestamps and explicit foreground, background, or unknown launch provenance.

## [2.4.0] - 2026-07-20

### Fixed

* Fixed non-finite floating-point span attributes blocking subsequent trace export from the in-memory batch queue.

### Changed

* Trace spans are now persisted in batches of up to 100 every 0.5 seconds, reducing disk activity and export overhead. Spans still buffered in memory may be lost if the app crashes or is force-terminated.

## [2.3.2] - 2026-07-09

### Added

* Custom error and exception reporting now includes crash-report-style metadata: `crash.processPath`, `exception.images`, and `exception.threads` stack frames with resolved binary image names. Configure via `CustomTrackingConfiguration.includeBinaryImagesOnErrors` (Swift) or `SPLKCustomTrackingConfiguration.includeBinaryImagesOnErrors` (Objective-C). #677

### Changed

* OTLP exporter `User-Agent` headers now identify the Splunk RUM agent version, OS name/version, and OTLP exporter package version. #682

### Fixed

* Fixed SDK-owned exporter uploads incorrectly being emitted as Network Instrumentation HTTP spans. Internal SDK requests are now excluded from network telemetry. #683

## [2.3.1] - 2026-06-15

### Fixed

* Fixed `ShowVC` and `PresentationTransition` timing spans incorrectly emitting `last.screen.name` with the destination screen name instead of the actual previous screen name. #662
* Fixed automated screen tracking incorrectly firing for internal UIKit controllers `UIEditingOverlayViewController` and `UITrackingElementWindowController`. #667
* Fixed `app.ui.navigation` spans incorrectly emitting `last.screen.name` with the value `"unknown"` on the first navigation event. The attribute is now omitted when no previous screen has been shown. #661
* Fixed the SwiftUI View modifier `sessionReplaySensitive` API ambiguity. #676

### Changed

* HTTP client spans now emit the OpenTelemetry `network.protocol.version` attribute instead of the deprecated `http.protocol.version` key. The attribute is omitted when the negotiated protocol version cannot be determined from response headers. #656

## [2.3.0] - 2026-05-18

### Added

* Added automated screen tracking for `UIViewController` transitions #590
* Added automated screen tracking for `UINavigationController` push/pop (including interactive pop cancellation) #587
* Added automated screen tracking for modal presentation/dismissal. #599
* Added manual screen name tracking via `track(screen:attributes:)` and the `.trackScreen` SwiftUI view modifier, with optional custom attributes. Manual calls bypass the `NavigationEventProcessor` and always emit spans. #621
* Added `NavigationEventProcessor` protocol (in `SplunkNavigation`; requires `import SplunkNavigation`) for custom screen name transforms, event filtering, and span attributes on navigation events. #624
* Added `navigation.name` attribute on `app.ui.navigation` screen-change spans. #625
* Added navigation module integration in `SplunkAgent` proxy with Swift and Objective-C API surfaces. #618

### Changed

* Navigation spans now use the span name `app.ui.navigation` (previously `screen name change`). #625

### Fixed

* Fixed xcframework build system. #647

## [2.2.3] - 2026-05-12

### Fixed

* Fixed nested frameworks in the CiscoSessionReplay.framework. Fixes #633. #654

## [2.2.2] - 2026-04-15

### Added

* Added public references to sessionWillResetNotification and sessionDidResetNotification. #614
* Added optional support to capture network headers. #604
* Session Replay now captures text content in wireframes for UIKit applications. #615

### Changed

* Updated endpoint from signalfx.com to observability.splunkcloud.com. #612

## [2.2.1] - 2026-03-19

### Added

* Added session metadata property (`Session.metadata`). #602
* Added session start timestamp (`SessionState.start`) and last activity timestamp (`SessionState.lastActivity`) to the public API. #602
* Added W3C trace context header injection for instrumented `URLSession` requests. #574
* Added `NetworkInstrumentationConfiguration.injectTraceHeaders` to allow disabling trace header injection. #574

## [2.2.0] - 2026-03-11

### Added

* Added support for the setting of endpointConfiguration to be deferred until after agent initialization. Disabling the endpoint is also supported with caching of pending spans. #457
* Added support for adjusting the Session Replay sampling rate. #575

### Changed

* The SDK now uses static binary dependencies to enhance integration in complex deployment scenarios. #593

## [2.1.0] - 2026-02-23

### Added

* XCFramework build system for binary distribution of the SDK. #568

### Changed

* Replaced OTLP binary protobuf with custom JSON encoding to reduce binary size. The SDK now uses `opentelemetry-swift-core` (API/SDK only) instead of the full `opentelemetry-swift` package with protocol exporters. #566

## [2.0.7] - 2026-02-04

### Fixed

* Fixed a SpanData race condition deallocation crash. Fixes #550. #562

## [2.0.6] - 2026-02-02

### Changed

* Updated Network Monitor to remove crashes during network radio change notifications.
* Updated and unpinned the opentelemetry-swift dependency to latest version, using the new split repos (opentelemetry-swift and opentelemetry-swift-core).
* Improved slow‑frame detection accuracy on variable refresh‑rate (ProMotion) displays.

### Fixed

* Updated Network Monitor to remove potential race condition.

## [2.0.5] - 2026-01-19

### Fixed

* Moved auth query parameter value for trace/log/replay exporters into X-SF-Token header.
* 'deploymentEnvironment', in configuration, must now contain a non-empty string.
* Fixed long cold app starts.

## [2.0.4] - 2025-12-01

### Added

* Added runtime support for iOS/iPadOS 13 and above.

### Fixed

* Fixed App Start event in case of a delayed agent install.
* Changed ios.state to ios.app.state in crash spans.

## [2.0.3]

### Added

* Added CFBundleVersion to Resources for inclusion in all spans via app.build_id. #494
* Extended the WKWebView BRUM session ID bridging facility down to iOS 13+. BRUM still only uses the initial sync on iOS 13, but iOS 14+ now exposes the async refresh path previously limited to iOS 15+ should BRUM opt in.

### Changed

* Updated the Network instrumentation to to use the network instrumentation style of 0.13. #490

## [2.0.2]

### Added

* Added compilation support for iOS 13 and 14. On these versions, the main agent remains inactive but will continue to handle pending crash reports. Full instrumentation features are available on iOS 15 and above. #466
* Add the app.installation.id attribute to all signals to uniquely identify each application installation. #452
* Added the session start event. #465 #475
* Added the session replay refresh event. #463

### Fixed

* Fixed SwiftLint and SwiftFormat plugins appearing when importing the agent #454
* Fixed occasional stalled url requests #448

## [2.0.1]

### Added

* Added missing ObjC APIs

### Fixed

* Fixed a bug in the ViewController transition navigation tracking
* Fixed SwiftUI UI element names in automatic navigation tracking

## [2.0.0]

This is a first major stable release of the new Splunk OpenTelemetry Agent.

### Added

* Added compile support for visionOS, tvOS, macOS Catalyst.
* Added Objective-C API.
* Added dSYM upload script.
* Implemented AppState module monitoring application state.

### Changed

* Updated DocC documentation.

### Fixed

* Various bugs.

## [2.0.0-alpha.1]

### Added

* Re-architected the SDK to be a modular Swift Package.
* Added Session Replay integration.
* Added Crash Report Symbolication integration.
* Added new Interaction Tracking feature to automatically capture user taps.
* Added `spanInterceptor` functionality for modifying or dropping spans.

### Changed

* The project is now distributed as a Swift Package named `SplunkAgent`.
* Dependency management now uses Swift Package Manager, replacing in-source dependencies and CocoaPods support.
* The agent now uses OTLP (HTTP/protobuf) for exporting signals. Zipkin support has been removed.

### Deprecated

* The legacy **`SplunkRumBuilder`** class and all of its methods are now deprecated. Users should migrate to using the `AgentConfiguration` struct and the `SplunkRum.install(with:)` method for initialization. The deprecated builder methods include:
    * `init(beaconUrl:rumAuth:)`
    * `init(realm:rumAuth:)`
    * `debug(enabled:)`
    * `deploymentEnvironment(environment:)`
    * `sessionSamplingRatio(samplingRatio:)`
    * `setApplicationName(_:)`
    * `enableDiskCache(enabled:)`
    * `globalAttributes(globalAttributes:)`
    * `showVCInstrumentation(_:)`
    * `screenNameSpans(enabled:)`
    * `slowRenderingDetectionEnabled(_:)`
    * `slowFrameDetectionThresholdMs(thresholdMs:)`
    * `frozenFrameDetectionThresholdMs(thresholdMs:)`
    * `networkInstrumentation(_:)`
    * `ignoreURLs(_:)`
    * `build()`
* Legacy **static functions** on the `SplunkRum` class are deprecated. Users should now access functionality through the singleton `SplunkRum.shared` instance. The deprecated static functions include:
    * `reportError(string:)`
    * `reportError(error:)`
    * `reportError(exception:)`
    * `reportEvent(name:attributes:)`
    * `integrateWithBrowserRum(_:)`
    * `setScreenName(_:)`
    * `addScreenNameChangeCallback(_:)`
    * `getSessionId()`
    * `isInitialized()`
    * `setGlobalAttributes(_:)`
    * `removeGlobalAttribute(_:)`
    * `debugLog(_:)`

### Removed

* The following legacy APIs have been removed and have no direct equivalent in the new architecture:
    * `setLocation(latitude: Double, longitude: Double)`
    * `spanDiskCacheMaxSize(size: Int64)`
    * `setSpanSchedulingDelay(seconds: TimeInterval)`
    * `allowInsecureBeacon(enabled: Bool)`

## [0.11.3](https://github.com/signalfx/splunk-otel-ios/releases/tag/0.11.3)

### Added

* Add option to toggle showVCInstrumentation [#179](https://github.com/signalfx/splunk-otel-ios/pull/179)

### Fixed

* Use session ID for source of randomness when making sampling decisions [#185](https://github.com/signalfx/splunk-otel-ios/pull/185)

## [0.11.2](https://github.com/signalfx/splunk-otel-ios/releases/tag/0.11.2)

### Added

* Implement Sampler protocol for SessionBasedSampler

### Fixed

* Fixes adding a link to a network span if traceparent is not the first key in the string

## [0.11.1](https://github.com/signalfx/splunk-otel-ios/releases/tag/0.11.1)

### Added

* Adds option for slowRenderingDetectionEnabled
* Adds option for bspScheduleDelay

## [0.11.0](https://github.com/signalfx/splunk-otel-ios/releases/tag/0.11.0)

### Added

* Adds reportEvent convenience function.
* Adds ability to import project through cocoapods.

### Deprecated

* Deprecates the use of SplunkRum.initialize. Use the SplunkRumBuilder going forward.
