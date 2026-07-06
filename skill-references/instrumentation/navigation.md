# Navigation

Load for SwiftUI screen tracking, UIKit view-controller tracking, storyboards,
tabs, navigation stacks, modals, custom containers, or screen-name migration.

## Depth guidance

- `baseline`: track only the key screen boundaries needed for the user's
  stated goal. Prefer manual or SwiftUI modifier placement at meaningful
  existing boundaries.
- `targeted`: cover primary user flows found during inspection, including
  tabs, modals, detail screens, or storyboard view controllers that automatic
  tracking would miss.
- `comprehensive`: propose a screen inventory across SwiftUI, UIKit,
  storyboards, custom containers, and mixed flows. Use automated tracking only
  after explaining its naming and coverage tradeoffs.

## Guidance

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
