# Custom Event and Workflow Reporting

This module provides APIs to manually track custom events, errors, and multi-step workflows.

> ``SplunkRum/customTracking``

| | |
|---|---|
| **Module** | `SplunkCustomTracking` |
| **Enabled by Default?** | Yes |
| **Public API?** | Yes |

## Overview

Use this module to report business-specific events or to trace the duration of custom workflows within your application.

## Usage Examples

### Tracking a Custom Event
```swift
SplunkRum.shared.customTracking.trackCustomEvent("user_signed_up")
```

### Tracking an Error
```swift
do {
    try performRiskyOperation()
} catch {
    SplunkRum.shared.customTracking.trackError(error)
}
```

### Tracking a Workflow
The trackWorkflow method returns a Span object that you are responsible for ending.

```swift
let checkoutSpan = SplunkRum.shared.customTracking.trackWorkflow("checkout_process")

// ... perform checkout steps ...

checkoutSpan.end() // The duration is now recorded
```
