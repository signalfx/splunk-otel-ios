# ``SplunkAgent/SessionReplayModulePreferences``

## Overview

The `SessionReplayModulePreferences` protocol defines the public API for the user's preferred settings related to Session Replay. These settings influence how the module behaves, though the actual state might differ.

## Topics

### Rendering Settings

- ``renderingMode``
  The video ``SplunkAgent/RenderingMode`` for captured data.
- ``renderingMode(_:)``
  Sets video ``SplunkAgent/RenderingMode`` for captured data.

### Initialization

- ``init(renderingMode:)``
  Initializes a new preferences object with preconfigured values.

