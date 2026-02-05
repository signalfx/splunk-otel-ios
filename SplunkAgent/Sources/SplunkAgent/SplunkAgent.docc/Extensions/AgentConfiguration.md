# ``SplunkAgent/AgentConfiguration``

## Overview

The `AgentConfiguration` struct defines the initial setup parameters for the Splunk RUM agent. It allows you to specify endpoints, application details, and various module settings. The endpoint is optional; if you omit it, the agent will cache telemetry until you configure an endpoint later via ``RuntimeState/setEndpoint(_:)``.

## Topics

### Initializers

- ``init(endpoint:appName:deploymentEnvironment:)``
- ``init(appName:deploymentEnvironment:)``
- ``init(from:)``

### Endpoint Settings

- ``endpoint``
  The endpoint configuration for the agent's data submission. If `nil`, the agent enters a caching state until you set an endpoint.
- ``endpoint(_:)``
  A builder method to set the endpoint configuration.
- ``enableDebugLogging``
  A boolean indicating whether debug logging is enabled for the agent.

### Application Details

- ``appName``
  The name of the application being monitored.
- ``appName(_:)``
  A method to set the application name during configuration.
- ``appVersion``
  The version of the application being monitored.
- ``appVersion(_:)``
  A method to set the application version during configuration.

### Session Sampling

- ``session``
  Configuration related to session sampling, including the sampling rate. (Assumes `session` is a public property of `AgentConfiguration` that contains `samplingRate`).

### User Tracking

- ``user``
  Configuration related to user tracking, including the user tracking mode. (Assumes `user` is a public property of `AgentConfiguration` that contains `trackingMode`).
