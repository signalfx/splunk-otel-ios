# Navigation

## Load when

Load for SwiftUI screen tracking, UIKit view-controller tracking, storyboards,
tabs, navigation stacks, modals, custom containers, or screen-name migration.

## Do not load when

Do not load for a Host App with no UI/navigation instrumentation task.

## Source files to verify

- `SplunkAgent/Sources/SplunkAgent/SplunkAgent.docc/Modules/Navigation-Tracking.md`
- `SplunkAgent/Sources/SplunkAgent/Public API/Modules/Navigation/`
- `SplunkNavigation/`
- `SplunkAgent/Sources/SplunkAgentObjC/Modules/Navigation/`
- Host App SwiftUI/UIKit/storyboard files

## Required output additions

- UI framework and navigation evidence.
- Automated versus manual tracking decision.
- Screen names and attribute privacy notes.

## Guidance

For SwiftUI, prefer `.trackScreen(...)` at meaningful screen boundaries. For
apps without an `AppDelegate`, this may be independent from install location.

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
