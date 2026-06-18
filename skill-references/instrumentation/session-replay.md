# Session Replay

## Load when

Load when Session Replay is requested, detected, migrated, reviewed, or
troubleshot.

## Do not load when

Do not load for default fresh install unless the user asks about Session Replay.

## Source files to verify

- `SplunkAgent/Sources/SplunkAgent/SplunkAgent.docc/Modules/Session-Replay.md`
- `SplunkAgent/Sources/SplunkAgent/Public API/Modules/Session Replay/`
- `SplunkAgent/Sources/SplunkAgentObjC/Modules/Session Replay/`
- Host App screens containing sensitive UI

## Required output additions

- Explicit user approval state.
- Masking/privacy checklist.
- Sensitive UI findings.
- Recording-state verification plan.

## Approval gate

Do not call `sessionReplay.start()` or equivalent ObjC APIs without explicit
user confirmation after reviewing masking, sampling, and sensitive screens.

Before enabling, identify:

- login, payment, account, health, message, profile, and PII screens
- UIKit views or SwiftUI views needing sensitivity masking
- WebViews that may record rendered content
- sampling and storage implications

Only include start/stop snippets after approval. Keep them out of top-level
`SKILLS.md` and fresh-install defaults.

After approval, source-backed Swift APIs include:

```swift
// UIKit masking
paymentField.srSensitive = true

// SwiftUI masking
SecureCheckoutView()
    .sessionReplaySensitive()

// Recording control
agent.sessionReplay.start()
agent.sessionReplay.stop()
```

`UITextView`, `UITextField`, and `WKWebView` are sensitive by default in
current source. Verify current source before relying on default masking for
custom controls.

Session Replay configuration is separate from starting recording. If sampling
is requested, verify `SessionReplayConfiguration(enabled:samplingRate:)` in
`SplunkSessionReplayProxy`; sampling is decided once per agent lifecycle and
values outside `<0, 1>` are clamped.
