# Crash Reporting

The Crash Reporting module captures and reports application crashes.

| | |
|---|---|
| **Module** | `SplunkCrashReports` |
| **Enabled by Default?** | Yes |
| **Public API?** | No (Automatic) |

This module automatically detects both native (e.g., `SIGSEGV`) and unhandled Swift/Objective-C exceptions. When the application is next launched, the crash report is processed and sent to Splunk RUM, enriched with device stats and the active session ID at the time of the crash.

## Configuration

You can disable crash reporting during initialization by providing a `CrashReportsConfiguration` object.

```swift
import SplunkAgent
import SplunkCrashReports // Required for the configuration type

let crashConfig = CrashReportsConfiguration(isEnabled: false)

// Pass it during agent installation
do {
    try SplunkRum.install(
        with: agentConfig,
        moduleConfigurations: [crashConfig]
    )
    ...
```
