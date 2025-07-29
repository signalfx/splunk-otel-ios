# ``SplunkAgent/SessionReplayModuleState``

## Overview

The `SessionReplayModuleState` protocol defines a public API for querying the current operational state of the Session Replay module. Its properties reflect a combination of default settings, initial configuration, remote settings, and user preferences.

## Topics

### Recording Status

- ``status``
  A ``SplunkAgent/SessionReplayStatus`` of the module's recording.
- ``isRecording``
  A boolean indicating whether the module is currently recording.

