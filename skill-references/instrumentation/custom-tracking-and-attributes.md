# Custom Tracking And Attributes

## Guidance

Do not add custom telemetry unless the user asks or an inspected gap blocks
useful verification. Use custom events for business milestones, handled errors
for expected error paths, and workflows for timed operations with clear
start/end points.

### Global attributes

Use global attributes for stable, non-sensitive context that belongs on every
signal. Configure initial values before installing the agent:

```swift
let configuration = AgentConfiguration(
    endpoint: endpointConfiguration,
    appName: appName,
    deploymentEnvironment: deploymentEnvironment
).globalAttributes(MutableAttributes(dictionary: [
    "app.release_channel": .string("beta")
]))
```

After installation, mutate the retained agent's public collection. Assign
`nil` to remove an attribute:

```swift
agent.globalAttributes[string: "app.release_channel"] = "production"
agent.globalAttributes[string: "app.release_channel"] = nil
```

Keep context that applies to only one event in that event's attributes.

### Custom tracking

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

Keep attributes low-cardinality and non-sensitive. Never add raw names, emails,
addresses, account numbers, auth identifiers, or other PII. Use the Host App's
existing privacy-approved redaction or tokenization before values reach
telemetry.

For ObjC global attributes, use `SPLKAgentConfiguration.globalAttributes`
before installation and `SPLKAgent.shared.globalAttributes` afterward. Assigning
the runtime property replaces the complete dictionary.

For ObjC, verify bridged API availability before suggesting selectors. Current
ObjC bridge supports custom events, error messages, `NSError`, and `NSException`;
do not claim ObjC workflow support unless current source adds it.
