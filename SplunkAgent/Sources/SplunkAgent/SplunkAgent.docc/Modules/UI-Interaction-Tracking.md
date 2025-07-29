# UI Interaction Tracking

The UI Interaction module automatically captures user taps on UI elements.

| | |
|---|---|
| **Module** | `SplunkInteractions` |
| **Enabled by Default?** | Yes |
| **Public API?** | Yes (for custom IDs) |

## Overview

This module creates spans for user interactions, such as button taps, to help you understand how users navigate and use your app. It automatically captures the element's class and accessibility label.

## Custom Identifiers

To provide more meaningful names for your interaction spans, you can assign a custom identifier to your views.

```swift
let myButton = UIButton()
myButton.splunkRumId = "login_button"
```

This will result in interaction spans being named "login_button" instead of the default.
