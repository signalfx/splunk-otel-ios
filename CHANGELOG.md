# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0-alpha]

### Added

* Re-architected the SDK to be a modular Swift Package.
* Added Session Replay integration.
* Added `spanInterceptor` functionality for modifying or dropping spans.
* Added new Interaction Tracking feature to automatically capture user taps.

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

## Unreleased

### Added

### Changed

### Deprecated

### Removed

### Fixed

### Security

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

