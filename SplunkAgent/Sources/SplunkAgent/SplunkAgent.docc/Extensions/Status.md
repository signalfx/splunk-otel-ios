# ``SplunkAgent/Status``

## Overview

The `Status` enum defines the possible operational states of the Splunk RUM agent, indicating whether it is running or not, and why.

## Topics

### Agent States

- ``running``
  Indicates that the agent is actively running and collecting data.
- ``notRunning(_:)``
  Indicates that the agent is currently not running, with an associated reason for its state.

