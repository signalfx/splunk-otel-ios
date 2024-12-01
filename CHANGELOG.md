# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### Added

### Changed

#### Dependency updates

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

* Deprecates the use of SplunkRum.initialize.  Use the SplunkRumBuilder going forward.
