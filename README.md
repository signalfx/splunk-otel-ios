
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

## License

This library is licensed under the terms of the Apache Softare License version 2.0.
See [the license file](./LICENSE) for more details.

>ℹ️&nbsp;&nbsp;SignalFx was acquired by Splunk in October 2019. See [Splunk SignalFx](https://www.splunk.com/en_us/investor-relations/acquisitions/signalfx.html) for more information.
