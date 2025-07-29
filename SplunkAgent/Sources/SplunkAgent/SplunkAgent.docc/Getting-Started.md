# Getting Started with Splunk RUM

This guide will walk you through installing and initializing the Splunk RUM agent for iOS in your project.

## Requirements

Splunk RUM agent for iOS supports iOS 15 and higher, including iPadOS 15 and higher.

## Installation

You can add Splunk RUM for iOS to your project using Swift Package Manager.

1. In Xcode, select **File > Add Package Dependencies...**
2. Enter the package URL: `https://github.com/signalfx/splunk-otel-ios`
3. Select the `SplunkAgent` package product and add it to your application target.

## Initialization

In your `AppDelegate.swift` or `@main` content file, import `SplunkAgent` and initialize it with your configuration.

```swift
import SplunkAgent

// In your application:didFinishLaunchingWithOptions or init()

let agentConfig = AgentConfiguration(
    endpoint: .init(realm: "<YOUR_REALM>", rumAccessToken: "<YOUR_RUM_ACCESS_TOKEN>"),
    appName: "<YOUR_APP_NAME>",
    deploymentEnvironment: "<YOUR_DEPLOYMENT_ENVIRONMENT>"
)

var agent: SplunkRum?

do {
    agent = try SplunkRum.install(with: agentConfig)
} catch {
    print("Unable to start the Splunk agent, error: \(error)")
}

// Example: Enable automated navigation tracking
agent?.navigation.preferences.enableAutomatedTracking = true

// Example: Start session replay
agent?.sessionReplay.start()
```

Once initialized, the agent will automatically begin collecting data for enabled modules.


