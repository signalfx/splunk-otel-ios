# Session Replay

Session Replay provides a visual replay of user sessions, helping you understand user behavior and debug issues.

> ``SplunkRum/sessionReplay``

| | |
|---|---|
| **Module** | `SplunkSessionReplayProxy` |
| **Enabled by Default?** | No (Requires manual start) |
| **Public API?** | Yes |

## Overview

This module captures the application's UI and user interactions to create a video-like replay of the user's session. It includes powerful privacy controls to mask sensitive information.

## Usage

Session Replay must be started manually after the agent is initialized.

```swift
// Start recording the user session
SplunkRum.shared.sessionReplay.start()
```

## Privacy and Sensitivity

By default, common sensitive views like `UITextField` and `UITextView` are masked. You can mark any `UIView` as sensitive to ensure it is redacted from the recording.

```swift
let sensitiveLabel = UILabel()
sensitiveLabel.srSensitive = true
```

For SwiftUI, use the `.sessionReplaySensitive()` view modifier.


