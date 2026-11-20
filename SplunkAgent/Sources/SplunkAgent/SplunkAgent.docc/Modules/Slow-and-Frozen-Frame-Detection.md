# Slow & Frozen Frame Detection

This module reports instances of slow or frozen UI frames, which are indicators of poor application performance.

| | |
|---|---|
| **Module** | `SplunkSlowFrameDetector` |
| **Enabled by Default?** | Yes |
| **Public API?** | Yes (for state checking) |

The module uses `CADisplayLink` to monitor the main thread's responsiveness. No manual setup is required.

A frame is classified as *slow* when it arrives late enough to have missed at least one complete presentation opportunity at the current display cadence. The cadence is derived per frame, so a legitimate refresh-rate change on a variable-refresh-rate (ProMotion) display is not misreported as slow. A frame is classified as *frozen* when the main thread is unresponsive for a significant period. The two classifications are mutually exclusive, and a single continuous freeze is reported once regardless of its duration.

Detected frames are periodically flushed as aggregated counts, not one span per frame. Nonzero counts are periodically emitted as `slowRenders` or `frozenRenders` spans carrying a `count` attribute.

> Tip: You can access all related API via SplunkRum instance property: ``SplunkRum/slowFrameDetector``

Assuming `agent` is the ``SplunkRum`` instance you retained after installation.

You can check if the module is currently active via its state property.
```swift
let isDetecting = agent?.slowFrameDetector.state.isEnabled ?? false
```
