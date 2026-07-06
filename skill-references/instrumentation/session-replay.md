# Session Replay

Load when Session Replay is requested, detected, reviewed, or troubleshot.
Also load for masking, sensitivity, SwiftUI redaction, custom view IDs,
rendering mode, recording masks, sampling, or recording state.

## Depth guidance

- `baseline`: do not start Session Replay by default. If explicitly approved,
  use the smallest safe enablement plan, conservative sampling, and masking for
  inspected sensitive screens.
- `targeted`: add approved sensitivity rules, stable custom IDs, or recording
  checks for specific screens and flows.
- `comprehensive`: propose a full Session Replay readiness pass covering
  sampling, sensitive UI, WebViews, custom controls, rendering mode, recording
  masks, endpoints, and backend verification. Apply only approved pieces.

## Approval gate

Do not call `sessionReplay.start()` or equivalent ObjC APIs without explicit
user confirmation after reviewing masking, sampling, and sensitive screens.

Before enabling, identify:

- login, payment, account, health, message, profile, and PII screens
- UIKit views or SwiftUI views needing sensitivity masking
- WebViews that may record rendered content
- custom controls, images, PDFs, charts, maps, or canvases that may render
  sensitive data without using standard text-input classes
- sampling and storage implications

Only include start/stop snippets after approval. Keep them out of top-level
`SKILLS.md` and fresh-install defaults.

## Public API boundary

Use Splunk RUM public APIs, not underlying implementation-only APIs, in
customer apps. Do not suggest recording quality, data producer hooks,
`onPublish`, or `deleteData` unless the current Splunk RUM public API exposes
the requested capability.

For Swift configuration types, verify imports. `SessionReplayConfiguration`
lives in `SplunkSessionReplayProxy`; normal app-facing recording, state,
sensitivity, custom ID, rendering, and mask APIs are reached through the
retained `SplunkRum` instance's `sessionReplay` property.

## Enablement, sampling, and endpoints

Session Replay module presence is not the same as recording. Current source can
create the module by default, but recording remains
`.notRecording(.notStarted)` until `agent.sessionReplay.start()` is called.

Use `SessionReplayConfiguration(enabled:samplingRate:)` only when the task asks
to enable, disable, or sample Session Replay:

```swift
import SplunkAgent
import SplunkSessionReplayProxy

let replayConfig = SessionReplayConfiguration(
    enabled: true,
    samplingRate: 0.25
)

let agent = try SplunkRum.install(
    with: configuration,
    moduleConfigurations: [replayConfig]
)
```

Sampling is decided once per agent lifecycle and is not re-evaluated on session
rotation. `nil` means equivalent to `1.0`; values outside `<0, 1>` are clamped.
If `enabled` is `false`, `start()` does nothing. If the launch is sampled out,
state should report `.notRecording(.disabledBySampling)`.

Deferred endpoint setup can still leave Session Replay operational at install.
When endpoint configuration is added later with `updateEndpoint(_:)`, cached
replay chunks can flush. Do not tell users Session Replay cannot be enabled
without immediate endpoint values; do report that backend confirmation requires
an endpoint and public access.

If a custom endpoint is approved and Session Replay is enabled, a custom trace
endpoint alone is not enough for Session Replay upload. `EndpointConfiguration`
with realm builds both trace and Session Replay endpoints; custom endpoint
setup has a separate optional `sessionReplay` URL.

## Sensitivity and masking

Current public API supports sensitivity at the instance level, class level, and
SwiftUI view modifier level. Instance sensitivity overrides class sensitivity.
Assigning `nil` removes an explicit sensitivity setting.

After approval, source-backed Swift APIs include:

```swift
// UIKit instance masking
paymentField.srSensitive = true

// UIKit class-level masking or unmasking
agent.sessionReplay.sensitivity[UITextField.self] = true
agent.sessionReplay.sensitivity[CustomBadgeView.self] = false

// SwiftUI masking
SecureCheckoutView()
    .sessionReplaySensitive()
```

`UITextView`, `UITextField`, and `WKWebView` are sensitive by default in current
source. Verify current source before relying on default masking for custom
controls. If a SwiftUI view encapsulates a native UIKit element, set the UIKit
element sensitivity first and then apply `.sessionReplaySensitive()` to the
SwiftUI wrapper when needed.

Use `false` deliberately. Marking a view or class explicitly non-sensitive can
unmask data that would otherwise be hidden by default or class-level rules.

## Custom identifiers

Custom IDs are useful for stable Session Replay and interaction analysis of
important UI elements. Keep IDs stable, low-cardinality, and non-sensitive. Do
not use names, emails, account IDs, order IDs, access tokens, URLs with private
paths, or user-entered text.

Swift API:

```swift
checkoutButton.splunkRumId = "checkout.submit"
agent.sessionReplay.customIdentifiers[totalLabel] = "checkout.total"
```

Custom IDs are separate from sensitivity. Adding an ID does not mask the view.

## Rendering mode and recording masks

Rendering mode is a preference; the actual mode in use should be checked from
`agent.sessionReplay.state.renderingMode`.

```swift
agent.sessionReplay.preferences
    .renderingMode(.wireframeOnly)
```

Supported public values are `.native` and `.wireframeOnly`; `.native` is the
current default. Treat rendering mode changes as privacy and product-behavior
changes that need explicit approval.

Use `RecordingMask` only when sensitivity APIs are not practical for an area.
Mask elements apply in order. `.covering` hides an area; `.erasing` cuts through
covered lower-layer mask areas. Empty masks are treated as no mask in current
source.

```swift
let mask = RecordingMask(elements: [
    MaskElement(
        rect: CGRect(x: 0, y: 0, width: 320, height: 80),
        type: .covering
    )
])

agent.sessionReplay.recordingMask = mask
```

Coordinate-based masks are brittle across device sizes, rotation, dynamic type,
and layout changes. Prefer view sensitivity whenever possible.

## Objective-C surfaces

For Objective-C apps, use `SplunkAgentObjC` and the verified ObjC surfaces:

- `SPLKSessionReplayConfiguration`
- `SPLKSessionReplayModule`
- `SPLKSessionReplayModuleSensitivity`
- `SPLKSessionReplayModuleCustomID`
- `SPLKRecordingMask`, `SPLKMaskElement`, `SPLKMaskElementType`
- `SPLKRenderingMode`
- `SPLKSessionReplayStatus`

Configuration and start example:

```objc
SPLKSessionReplayConfiguration *replayConfig =
    [[SPLKSessionReplayConfiguration alloc] initWithEnabled:YES
                                               samplingRate:@0.25];

SPLKAgent *agent = [SPLKAgent installWith:configuration
                     moduleConfigurations:@[replayConfig]
                                    error:&error];

// Only after explicit user approval and privacy review:
[agent.sessionReplay start];
```

Sensitivity and custom IDs:

```objc
[agent.sessionReplay.sensitivity setSensitivity:@YES forView:paymentField];
[agent.sessionReplay.sensitivity setSensitivity:@YES forViewClass:UITextField.class];
[agent.sessionReplay.customIdentifiers setCustomID:@"checkout.submit"
                                           forView:checkoutButton];
```

Rendering mode:

```objc
agent.sessionReplay.preferences.renderingMode = SPLKRenderingMode.wireframeOnly;
```

Avoid Swift-only snippets in `.m` files. Do not add a Swift wrapper only to
configure Session Replay in an Objective-C app.

## Recording control and state

After approval, start and stop through the retained agent:

```swift
agent.sessionReplay.start()
agent.sessionReplay.stop()
```

`stop()` is mainly for pausing recording; app exit does not require an explicit
stop call.

State API:

```swift
let status = agent.sessionReplay.state.status
let isRecording = agent.sessionReplay.state.isRecording
let renderingMode = agent.sessionReplay.state.renderingMode
let samplingRate = agent.sessionReplay.state.samplingRate
```

Known public status causes include: `.notStarted`, `.stopped`,
`.internalError`, `.swiftUIPreviewContext`, `.unsupportedPlatform`,
`.storageLimitReached`, and `.disabledBySampling`.

Do not print raw internal errors or private diagnostics while reporting state.

Do not start Session Replay during default local signal generation. Do not
attempt backend replay confirmation from non-operational platform runs.
