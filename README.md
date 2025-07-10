<p align="center">
  <strong>
    <a href="CONTRIBUTING.md">Getting Involved</a>
    &nbsp;&nbsp;&bull;&nbsp;&nbsp;
    <a href="SECURITY.md">Security</a>
  </strong>
</p>

<p align="center">
  <img alt="Stable" src="https://img.shields.io/badge/status-stable-informational?style=for-the-badge">
  <a href="https://github.com/open-telemetry/opentelemetry-swift/releases/tag/1.14.0">
    <img alt="OpenTelemetry Swift" src="https://img.shields.io/badge/otel-1.14.0-blueviolet?style=for-the-badge">
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

The Splunk RUM agent for iOS is a modular Swift package for Real User Monitoring.

> :construction: This project is currently in **ALPHA**. It is **officially supported** by Splunk. However, breaking changes **MAY** be introduced.

## Requirements

Splunk RUM agent for iOS supports iOS 15 and higher, including iPadOS 15 and higher.

## Getting Started

### Installation

You can add Splunk RUM for iOS to your project using Swift Package Manager.

1. In Xcode, select **File > Add Packages...**
2. Enter the package URL: `https://github.com/signalfx/splunk-otel-ios`
3. Select the `SplunkAgent` package product and add it to your application target.

### Initialization

In your `AppDelegate.swift` or `@main` content file, import `SplunkAgent` and initialize it with your configuration.

```swift
import SplunkAgent

// In your application:didFinishLaunchingWithOptions or init()
let agentConfig = AgentConfiguration(
    endpoint: .init(realm: "<YOUR_REALM>", rumAccessToken: "<YOUR_RUM_ACCESS_TOKEN>"),
    appName: "<YOUR_APP_NAME>",
    deploymentEnvironment: "<YOUR_DEPLOYMENT_ENVIRONMENT>"
)

// This will throw an exception if the configuration is invalid
try! SplunkRum.install(with: agentConfig)
```

## Features

The agent provides several instrumentations to capture telemetry. Most are enabled by default and can be configured or disabled during initialization.

* **Crash Reporting:** Captures and reports application crashes. (Enabled by default)
* **Network Monitoring:** Reports network requests, connectivity changes, and errors. (Enabled by default)
* **Application Startup:** Measures cold and warm application start times. (Enabled by default)
* **Slow & Frozen Frame Detection:** Reports instances of slow or frozen UI frames. (Enabled by default)
* **UI Interaction Tracking:** Captures user taps on UI elements. (Enabled by default)
* **Navigation Tracking:** Reports screen transitions as `screen.name` attributes. (Disabled by default)
* **Session Replay:** Provides visual replay of user sessions. (Requires separate module)
* **WebView Instrumentation:** Links native RUM sessions with Browser RUM sessions in WebViews.
* **Custom Event & Workflow Reporting:** APIs to manually track custom events and workflows.

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md) for instructions on building, running tests, and so on.

## License

This library is licensed under the terms of the Apache Software License version 2.0.
See [the license file](./LICENSE) for more details.

> :information_source:️ SignalFx was acquired by Splunk in October 2019. See [Splunk SignalFx](https://www.splunk.com/en_us/investor-relations/acquisitions/signalfx.html) for more information.
