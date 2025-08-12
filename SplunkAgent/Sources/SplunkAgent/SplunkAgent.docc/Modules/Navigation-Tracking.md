# Navigation Tracking

The Navigation module reports screen transitions and attaches the current screen name to all generated spans.

| | |
|---|---|
| **Module** | `SplunkNavigation` |
| **Enabled by Default?** | No |
| **Public API?** | Yes |

This module can be configured to automatically track `UIViewController` transitions or be used to set screen names manually. The active screen name (or "unknown" if not set) is added as a `screen.name` attribute to all telemetry.

> Tip: You can access all related API via SplunkRum instance property: ``SplunkRum/navigation``

## Configuration and Usage

Assuming `agent` is the ``SplunkRum`` instance you retained after installation.

### Automated Tracking
To enable automatic screen name tracking, set the preference after initialization:

```swift
agent?.navigation.preferences.enableAutomatedTracking = true
```

### Manual Tracking

You can manually set the screen name at any time. This is useful for SwiftUI apps or complex navigation flows.

```swift
agent?.navigation.track(screen: "ProductDetailView")
```