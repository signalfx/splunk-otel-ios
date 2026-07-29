# Session Replay Privacy And Rendering

## Sensitivity and masking

Current public API supports sensitivity at the instance, class, and SwiftUI
view-modifier levels. Instance sensitivity takes precedence over class
sensitivity, and assigning `nil` removes an explicit setting.

Source-backed Swift APIs:

```swift
paymentField.srSensitive = true
agent.sessionReplay.sensitivity[UITextField.self] = true
agent.sessionReplay.sensitivity[CustomBadgeView.self] = false

SecureCheckoutView()
    .sessionReplaySensitive()
```

`UITextView`, `UITextField`, and `WKWebView` are sensitive by default in current
source. Verify custom controls. When SwiftUI wraps a UIKit element, set UIKit
sensitivity first and then apply `.sessionReplaySensitive()` when needed.

Use `false` deliberately: it can unmask data hidden by default or class rules.

## Custom identifiers

Keep custom IDs stable, low-cardinality, and non-sensitive:

```swift
checkoutButton.splunkRumId = "checkout.submit"
agent.sessionReplay.customIdentifiers[totalLabel] = "checkout.total"
```

`splunkRumId` labels both Session Replay and interaction spans. Direct
`sessionReplay.customIdentifiers` assignments affect Session Replay only.
Custom IDs do not mask views.

## Rendering mode and recording masks

Rendering mode is a preference; inspect the active mode through
`agent.sessionReplay.state.renderingMode`.

```swift
agent.sessionReplay.preferences
    .renderingMode(.wireframeOnly)
```

Supported public values are `.native` and `.wireframeOnly`; `.native` is the
current default. Require approval because changing the mode affects privacy and
product behavior.

Use `RecordingMask` only when view sensitivity is impractical. Elements apply
in order: `.covering` hides an area and `.erasing` cuts through covered
lower-layer areas. An empty mask is treated as no mask.

```swift
let mask = RecordingMask(elements: [
    MaskElement(
        rect: CGRect(x: 0, y: 0, width: 320, height: 80),
        type: .covering
    )
])

agent.sessionReplay.recordingMask = mask
```

Coordinate masks are brittle across device sizes, rotation, dynamic type, and
layout changes. Prefer view sensitivity.
