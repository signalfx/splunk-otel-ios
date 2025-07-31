# Getting Started with Splunk RUM

This guide will walk you through installing and initializing the Splunk RUM agent for iOS. The primary entry point for all agent interactions is the ``SplunkRum`` instance you receive and retain after installation.

## Requirements

Splunk RUM agent for iOS supports iOS 15 and higher, including iPadOS 15 and higher.

## Installation

To add Splunk RUM for iOS to your project, use Swift Package Manager.

1. In Xcode, select **File > Add Package Dependencies...**
2. Enter the package URL: `https://github.com/signalfx/splunk-otel-ios`
3. Select the `SplunkAgent` package product and add it to your application target.

## Configuration

Before you can install the agent, you must create an ``AgentConfiguration`` instance. This object tells the agent where to send data and provides essential metadata about your application.

```swift
import SplunkAgent

let agentConfig = AgentConfiguration(
    endpoint: .init(realm: "<YOUR_REALM>", rumAccessToken: "<YOUR_RUM_ACCESS_TOKEN>"),
    appName: "<YOUR_APP_NAME>",
    deploymentEnvironment: "<YOUR_DEPLOYMENT_ENVIRONMENT>"
)
```
For a detailed overview of all available settings, see the ``AgentConfiguration`` documentation.

## Initialization

In a central part of your application, like your `AppDelegate` or main `App` struct, call `SplunkRum.install(with:)`. This method returns a ``SplunkRum`` instance that you should retain for the lifetime of your application to interact with the agent.

```swift
import SplunkAgent

class AppDelegate: UIResponder, UIApplicationDelegate {

    var agent: SplunkRum?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        let agentConfig = AgentConfiguration(
            endpoint: .init(realm: "<YOUR_REALM>", rumAccessToken: "<YOUR_RUM_ACCESS_TOKEN>"),
            appName: "<YOUR_APP_NAME>",
            deploymentEnvironment: "<YOUR_DEPLOYMENT_ENVIRONMENT>"
        )

        do {
            // The install(with:) method returns the agent instance
            self.agent = try SplunkRum.install(with: agentConfig)
        } catch {
            print("Unable to start the Splunk agent, error: \(error)")
        }

        // Example: Enable automated navigation tracking
        agent?.navigation.preferences.enableAutomatedTracking = true

        // Example: Start session replay
        agent?.sessionReplay.start()

        return true
    }
}
```

Once initialized, the agent will automatically begin collecting data. To explore what you can do next, see our <doc:Modules-Overview>.