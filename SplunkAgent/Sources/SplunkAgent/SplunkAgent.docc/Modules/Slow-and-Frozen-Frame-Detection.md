# Slow & Frozen Frame Detection

This module reports instances of slow or frozen UI frames, which are indicators of poor application performance.

| | |
|---|---|
| **Module** | `SplunkSlowFrameDetector` |
| **Enabled by Default?** | Yes |
| **Public API?** | Yes (for state checking) |

The module uses `CADisplayLink` to monitor the main thread's responsiveness. It automatically creates spans when slow or frozen frames are detected. No manual setup is required.

> SplunkRum instance property: ``SplunkRum/slowFrameDetector``

Assuming `agent` is the ``SplunkRum`` instance you retained after installation.

You can check if the module is currently active via its state property.
```swift
let isDetecting = agent?.slowFrameDetector.state.isEnabled ?? false
```