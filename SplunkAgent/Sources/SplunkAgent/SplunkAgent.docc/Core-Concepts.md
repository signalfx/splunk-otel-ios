# Core Concepts

Understanding the core components of the Splunk RUM agent will help you configure and use it effectively.

## The SplunkRum Singleton

The ``SplunkRum`` class is the main entry point for interacting with the agent. After installation, you access all public APIs and module-specific functionalities through the shared singleton instance: `SplunkRum.shared`.

```swift
// Access the navigation module to set a screen name
SplunkRum.shared.navigation.track(screen: "HomePage")

// Access the custom tracking module to track a string error message
SplunkRum.shared.customTracking.trackError("Failed to load user profile")
```

## Agent Configuration

The AgentConfiguration struct is used to provide all initial settings for the agent during installation. It is a required parameter for the `SplunkRum.install(with:)` method.

Key properties you must provide:

`endpoint`: Specifies the Splunk realm and RUM access token.
`appName`: Your application's name.
`deploymentEnvironment`: The environment, such as production or staging.

You can also provide optional configurations for modules, global attributes, and other settings using the builder-style methods on the `AgentConfiguration` instance.

## Module Configurations

While the main `AgentConfiguration` handles global settings, some modules have their own specific configuration structs (e.g., `SplunkNavigation.NavigationConfiguration`). These are passed as an optional array to the `SplunkRum.install(with:moduleConfigurations:)` method to override default module behaviors.

