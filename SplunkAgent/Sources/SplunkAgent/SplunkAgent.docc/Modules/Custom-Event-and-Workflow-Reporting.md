# Custom Event and Workflow Reporting

This module provides APIs to manually track custom events, errors, and multi-step workflows.


| | |
|---|---|
| **Module** | `SplunkCustomTracking` |
| **Enabled by Default?** | Yes |
| **Public API?** | Yes |

Use this module to report business-specific events or to trace the duration of custom workflows within your application.

> Tip: You can access all related API via SplunkRum instance property: ``SplunkRum/customTracking``

## Usage Examples

Assuming `agent` is the ``SplunkRum`` instance you retained after installation.

### Tracking a Custom Event
```swift
agent?.customTracking.trackCustomEvent("user_signed_up")
```

### Tracking an Error
```swift
do {
    try performRiskyOperation()
} catch {
    agent?.customTracking.trackError(error)
}
```

### Tracking a Workflow
The trackWorkflow method returns a Span object that you are responsible for ending.

```swift
let checkoutSpan = agent?.customTracking.trackWorkflow("checkout_process")

// ... perform checkout steps ...

checkoutSpan?.end() // The duration is now recorded
```