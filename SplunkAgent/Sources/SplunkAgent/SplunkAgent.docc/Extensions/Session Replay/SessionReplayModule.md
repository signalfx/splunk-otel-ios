# ``SplunkAgent/SessionReplayModule``

## Overview

The `SessionReplayModule` protocol defines the public API for interacting with the Session Replay functionality within the Splunk RUM agent. It provides access to session recording management, view sensitivity settings, custom view identifiers, and the current state and preferences of the module.

## Topics

### Recording Management

- ``start()``
  Starts recording a user session.
- ``stop()``
  Stops the currently running user session recording.

### Module Components

- ``sensitivity``
  An object that holds and manages view elements sensitivity, a ``SplunkAgent/SessionReplayModuleSensitivity`` instance.
- ``customIdentifiers``
  An object that holds and manages view elements custom identifiers, a ``SplunkAgent/SessionReplayModuleCustomId`` instance.
- ``state``
  An object that reflects the current state and settings used for the recording, a ``SplunkAgent/SessionReplayModuleState`` instance.
- ``preferences``
  An object that holds preferred settings for the recording, a ``SplunkAgent/SessionReplayModulePreferences`` instance.

### Module Configuration

- ``preferences(_:)``
  Sets preferred settings for the recording.
- ``recordingMask``
  The ``SplunkAgent/RecordingMask``, covers possibly sensitive areas.
- ``recordingMask(_:)``
  Sets a recording mask that covers possibly sensitive areas.

