# Slow & Frozen Frame Detection

This module reports instances of slow or frozen UI frames, which are indicators of poor application performance.

> ``SplunkRum/slowFrameDetector``

| | |
|---|---|
| **Module** | `SplunkSlowFrameDetector` |
| **Enabled by Default?** | Yes |
| **Public API?** | Yes (for state checking) |

## Overview

The module uses `CADisplayLink` to monitor the main thread's responsiveness. It automatically creates spans when slow or frozen frames are detected. No manual setup is required.

You can check if the module is currently active via its state property.
```swift
let isDetecting = SplunkRum.shared.slowFrameDetector.state.isEnabled
```



