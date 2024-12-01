---

<p align="center">
  <strong>
    <a href="CONTRIBUTING.md">Getting Involved</a>
    &nbsp;&nbsp;&bull;&nbsp;&nbsp;
    <a href="SECURITY.md">Security</a>
  </strong>
</p>

<p align="center">
  <img alt="Stable" src="https://img.shields.io/badge/status-stable-informational?style=for-the-badge">
  <a href="https://github.com/open-telemetry/opentelemetry-swift/releases/tag/1.5.0">
    <img alt="OpenTelemetry Swift" src="https://img.shields.io/badge/otel-1.5.0-blueviolet?style=for-the-badge">
  </a>
  <a href="https://github.com/signalfx/gdi-specification/releases/tag/v1.6.0">
    <img alt="Splunk GDI specification" src="https://img.shields.io/badge/GDI-1.6.0-blueviolet?style=for-the-badge">
  </a>
  <a href="https://github.com/signalfx/splunk-otel-ios/releases">
    <img alt="GitHub release (latest SemVer)" src="https://img.shields.io/github/v/release/signalfx/splunk-otel-ios?include_prereleases&style=for-the-badge">
  </a>
  <a href="https://github.com/signalfx/splunk-otel-ios/actions/workflows/ci.yml">
    <img alt="Build Status" src="https://img.shields.io/github/actions/workflow/status/signalfx/splunk-otel-ios/.github/workflows/ci.yml?branch=main&style=for-the-badge">
  </a>
</p>

---

# Splunk RUM agent for iOS

The Splunk RUM agent for iOS provides a Swift package that captures:

- HTTP requests, using `URLSession` instrumentation
- Application startup information
- UI activity - screen name (typically ViewController name), actions, and PresentationTransitions
- Crashes/unhandled exceptions using [SplunkRumCrashReporting](https://github.com/signalfx/splunk-otel-ios-crashreporting)

> :construction: This project is currently in **BETA**. It is **officially supported** by Splunk. However, breaking changes **MAY** be introduced.

## Requirements

Splunk RUM agent for iOS supports iOS 11 and higher, including iPadOS 13 and higher.

## Getting Started

To get started, see [Instrument iOS applications for Splunk RUM](https://quickdraw.splunk.com/redirect/?product=Observability&version=current&location=rum.ios.getstarted) in the Splunk Observability Cloud documentation.

### Crash Reporting

The Splunk iOS Crash Reporting module adds crash reporting to the iOS RUM agent using PLCrashReporter.

To activate Crash Reporting, see [Activate crash reporting](https://quickdraw.splunk.com/redirect/?product=Observability&version=current&location=rum.ios.crashreporting) in the Splunk Observability Cloud documentation.

### Manual OpenTelemetry instrumentation

You can manually instrument iOS applications for Splunk RUM using the iOS RUM agent to collect additional telemetry, sanitize Personal Identifiable Information (PII), add global attributes, and more. See [Manually instrument iOS applications](https://quickdraw.splunk.com/redirect/?product=Observability&version=current&location=rum.ios.manual) in the Splunk Observability Cloud documentation.

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md) for instructions on building, running tests, and so on.

## Troubleshooting

For troubleshooting issues with the Splunk OpenTelemetry iOS instrumentation, see [Troubleshoot iOS instrumentation for Splunk Observability Cloud](https://docs.splunk.com/Observability/gdi/get-data-in/rum/ios/troubleshooting.html) in the official documentation.

## License

This library is licensed under the terms of the Apache Softare License version 2.0.
See [the license file](./LICENSE) for more details.

>ℹ️&nbsp;&nbsp;SignalFx was acquired by Splunk in October 2019. See [Splunk SignalFx](https://www.splunk.com/en_us/investor-relations/acquisitions/signalfx.html) for more information.
