# Custom Tracking And Attributes

Load for custom events, handled errors, workflows, user/session/global
attributes, or business telemetry recommendations.

## Depth guidance

- `baseline`: do not add custom telemetry unless the user asks for it or a
  specific gap is blocking useful verification.
- `targeted`: add a small number of stable events, handled errors, or
  attributes for inspected critical flows.
- `comprehensive`: propose a business-signal map covering key milestones,
  handled failures, and timed workflows with clear owners for span completion.
  Apply only approved signals.

## Guidance

Recommend custom events for business milestones, handled errors for expected
error paths, and workflows for timed operations with clear start/end points.

Source-backed Swift APIs:

```swift
let attributes = MutableAttributes(dictionary: [
    "checkout.step": .string("shipping"),
    "cart.item_count": .int(3)
])

agent.customTracking.trackCustomEvent("checkout_step_viewed", attributes)
agent.customTracking.trackError("checkout_validation_failed")
```

`trackWorkflow(_:)` returns an OpenTelemetry `Span`; only recommend workflows
when the Host App has a clear owner for ending the span.

Keep attributes low-cardinality and non-sensitive. Do not add names, emails,
addresses, account numbers, auth identifiers, or other PII unless the user has
explicit product/privacy approval and a safe policy.

For ObjC, verify bridged API availability before suggesting selectors. Current
ObjC bridge supports custom events, error messages, `NSError`, and `NSException`;
do not claim ObjC workflow support unless current source adds it.
