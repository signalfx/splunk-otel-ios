# Navigation

## Guidance

Track only meaningful screen boundaries required by the user's goal. Broaden
coverage from an inspected screen inventory, and explain automated tracking's
naming and coverage tradeoffs before enabling it.

For SwiftUI, prefer `.trackScreen(...)` at meaningful screen boundaries:

```swift
import SplunkAgent

DetailView()
    .trackScreen("Product Detail", attributes: [
        "screen.source": "catalog"
    ])
```

For manual tracking from retained agent code, use
`agent.navigation.track(screen:attributes:)`. Keep screen names stable and
avoid user-specific values.

For UIKit, automated view-controller tracking can help, but use manual tracking
for tab changes, custom containers, or business screen names that automatic
tracking cannot infer.

To enable automated tracking during install, verify the current
`SplunkNavigation.NavigationConfiguration` API and import `SplunkNavigation` for
the configuration type:

```swift
import SplunkAgent
import SplunkNavigation

let navigationConfig = NavigationConfiguration(enableAutomatedTracking: true)
```

At runtime, the retained agent also exposes
`agent.navigation.preferences.enableAutomatedTracking`.

For storyboards, avoid storyboard edits unless needed. Prefer adding tracking in
existing view-controller or app lifecycle code.

For ObjC navigation, load `objc/uikit-storyboards-navigation.md`.
