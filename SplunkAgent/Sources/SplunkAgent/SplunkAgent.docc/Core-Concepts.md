# Core Concepts

Understanding the core components of the Splunk RUM agent will help you configure and use it effectively.

## The SplunkRum Instance

The ``SplunkRum`` class is the main entry point for interacting with the agent. The static `SplunkRum.install(with:)` method initializes and returns a ``SplunkRum`` instance. You should store this instance and use it for all subsequent interactions with the agent's modules.

```swift
// Assuming 'agent' is the instance you stored after installation
// Access the navigation module to set a screen name
agent?.navigation.track(screen: "HomePage")

// Access the custom tracking module to track a string error message
agent?.customTracking.trackError("Failed to load user profile")
```

## Agent Configuration

The ``AgentConfiguration`` struct is used to provide all initial settings for the agent. A configured instance is a required parameter for the `SplunkRum.install(with:)` method.

Key properties you must provide:

- `endpoint`: Specifies the Splunk realm and RUM access token.
- `appName`: Your application's name.
- `deploymentEnvironment`: The environment, such as `production` or `staging`.

You can also provide optional configurations for global attributes and other settings. See <doc:Getting-Started> for a practical example.

## Module Configurations

While the main ``AgentConfiguration`` handles global settings, some modules have their own specific configuration structs (e.g., `SplunkNetwork.NetworkInstrumentationConfiguration`). These are passed as an optional array to the `SplunkRum.install(with:moduleConfigurations:)` method to override default module behaviors.

For a complete list of available modules and their capabilities, see the <doc:Modules-Overview>.