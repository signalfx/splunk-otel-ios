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

For UIKit, automated view-controller tracking can help, but use manual tracking
for tab changes, custom containers, or business screen names that automatic
tracking cannot infer.

For storyboards, avoid storyboard edits unless needed. Prefer adding tracking in
existing view-controller or app lifecycle code.

For ObjC navigation, load `objc/uikit-storyboards-navigation.md`.

