# Navigation Tracking

The Navigation module reports screen transitions and attaches the current screen name to all generated spans.

> ``SplunkRum/navigation``

| | |
|---|---|
| **Module** | `SplunkNavigation` |
| **Enabled by Default?** | No |
| **Public API?** | Yes |

## Overview

This module can be configured to automatically track `UIViewController` transitions or be used to set screen names manually. The active screen name (or "unknown" if not set) is added as a `screen.name` attribute to all telemetry.

## Configuration and Usage

### Automated Tracking
To enable automatic screen name tracking, set the preference after initialization:

```swift
SplunkRum.shared.navigation.preferences.enableAutomatedTracking = true
```

### Manual Tracking

You can manually set the screen name at any time. This is useful for SwiftUI apps or complex navigation flows.

```swift
SplunkRum.shared.navigation.track(screen: "ProductDetailView")
```


