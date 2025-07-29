# ``SplunkAgent/AgentConfiguration``

## Overview

The `AgentConfiguration` struct defines the initial setup parameters for the Splunk RUM agent. It allows you to specify endpoints, application details, and various module settings.

## Topics

### Initializers

- ``init(url:)``
  Initializes the configuration with a specific URL.
- ``init(from:)``
  Initializes the configuration from a decoder.

### Endpoint Settings

- ``url``
  The primary URL for the agent's data submission.
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
