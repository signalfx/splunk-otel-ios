# Session Replay

Session Replay provides a visual replay of user sessions, helping you understand user behavior and debug issues.

| | |
|---|---|
| **Module** | `SplunkSessionReplayProxy` |
| **Enabled by Default?** | No (Requires manual start) |
| **Public API?** | Yes |

This module captures the application's UI and user interactions to create a video-like replay of the user's session. It includes powerful privacy controls to mask sensitive information.

> Tip: You can access all related API via SplunkRum instance property: ``SplunkRum/sessionReplay``

## Usage

Assuming `agent` is the ``SplunkRum`` instance you retained after installation.

Session Replay must be started manually.

```swift
// Start recording the user session
agent?.sessionReplay.start()
```

## Interaction Capture

Use ``SessionReplayModulePreferences/interactionCapture`` to control which categories of user interactions
are included in Session Replay. All categories are enabled by default, and changes affect only interactions
captured after the setting is updated.

```swift
let capture = agent?.sessionReplay.preferences.interactionCapture
capture?.isKeyboardEnabled = false
capture?.isRageTapEnabled = false
```

Use ``SessionReplayModuleInteractionCapture/enableAll()`` or
``SessionReplayModuleInteractionCapture/disableAll()`` to update every configurable category at once.

Interaction capture preferences are included when ``SessionReplayPreferences`` is encoded. When decoding
older or partial data, missing interaction categories remain enabled by default.

## Privacy and Sensitivity

By default, common sensitive views like `UITextField` and `UITextView` are masked. You can mark any `UIView` as sensitive to ensure it is redacted from the recording.

```swift
let sensitiveLabel = UILabel()
sensitiveLabel.srSensitive = true
```

For SwiftUI, use the `.sessionReplaySensitive()` view modifier.
