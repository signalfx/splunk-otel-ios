# Default Modules

## Load when

Load when explaining SDK defaults, app startup/state, crash runtime behavior,
slow/frozen frames, or interaction tracking.

## Do not load when

Do not load for a narrow task involving only high-risk feature setup.

## Source files to verify

- `SplunkAgent/Sources/SplunkAgent/SplunkAgent.docc/Modules-Overview.md`
- `SplunkAgent/Sources/SplunkAgent/SplunkAgent.docc/Modules/App-Startup-Tracking.md`
- `SplunkAgent/Sources/SplunkAgent/SplunkAgent.docc/Modules/Crash-Reporting.md`
- `SplunkAgent/Sources/SplunkAgent/SplunkAgent.docc/Modules/Slow-and-Frozen-Frame-Detection.md`
- `SplunkAgent/Sources/SplunkAgent/SplunkAgent.docc/Modules/UI-Interaction-Tracking.md`
- public API module configuration files

## Required output additions

- Which default modules are relevant.
- Any explicit module configuration changes proposed.
- Approval needed for config changes that alter behavior.

## Guidance

Distinguish module presence from active signal behavior. Current source builds
the default module pool from available modules: app start, app state, crash
reports, Session Replay, navigation, network, network monitor, slow frame
detector, WebView, custom tracking, and interactions.

Treat app startup, app state, crash runtime capture, network instrumentation,
network monitor, slow/frozen frame detection, interactions, and custom tracking
as baseline capabilities, subject to current source and module configuration.

Navigation module `isEnabled` defaults to `true`, but automated tracking
defaults to `false`; manual tracking and SwiftUI `.trackScreen(...)` remain
available when the module is operational.

Network instrumentation defaults to enabled with trace-header injection enabled
and header capture disabled. URL exclusion and header capture require explicit
module configuration.

Session Replay can be present and configured, but recording defaults to
`.notRecording(.notStarted)` until `sessionReplay.start()` is called. Treat
starting recording as a gated high-risk action.

WebView instrumentation can be present, but Browser RUM correlation requires an
explicit `integrateWithBrowserRum` call for each approved `WKWebView`.

Crash runtime capture is separate from dSYM upload. Use
`release/crash-and-dsym.md` for symbolication upload setup.

Do not promise exact backend visibility without verification. Report selected
signal types and how they will be exercised.
