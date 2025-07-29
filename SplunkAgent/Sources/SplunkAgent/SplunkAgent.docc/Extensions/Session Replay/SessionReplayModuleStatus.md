# ``SplunkAgent/SessionReplayStatus``

## Overview

The `SessionReplayStatus` enum describes the possible operational states for Session Replay recording, indicating whether the module is actively recording or not, and the reason if it's not.

## Topics

### Cases

- ``recording``
  Indicates that recording has been started and is currently in progress.
- ``notRecording(_:)``
  Indicates that recording is not in progress, with a specific ``SplunkAgent/SessionReplayStatus/Cause`` determining the reason.

### Causes (Nested Enum)

- ``notStarted``
  The recording has not yet started during this application launch.
- ``stopped``
  The user stopped the previous recording session.
- ``internalError``
  It was impossible to start recording due to an internal error (e.g., database issue).
- ``swiftUIPreviewContext``
  Recording is disabled in the SwiftUI Preview context.
- ``unsupportedPlatform``
  Recording is not supported on the current platform.
- ``storageLimitReached``
  The disk cache has overreached its allowed size, preventing further recording.

