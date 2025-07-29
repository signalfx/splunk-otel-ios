# Network Monitoring

The Network Monitoring modules automatically instrument `URLSession` requests and report network connectivity changes.

| | |
|---|---|
| **Modules** | `SplunkNetwork`, `SplunkNetworkMonitor` |
| **Enabled by Default?** | Yes |
| **Public API?** | Yes (for configuration) |

## Overview

**`SplunkNetwork`** automatically captures HTTP requests made via `URLSession`, reporting them as spans with details like URL, method, status code, and duration. Requests to the Splunk ingest endpoint are automatically ignored.

**`SplunkNetworkMonitor`** detects changes in network status (e.g., connected/disconnected) and connection type (Wi-Fi/cellular) and reports them as events.

## Configuration

You can provide an `NSRegularExpression` to ignore certain URL patterns during initialization.

```swift
import SplunkAgent
import SplunkNetwork // Required for the configuration type

// Ignore requests to 'api.internal.com'
let ignoreRegex = try! NSRegularExpression(pattern: "api\\.internal\\.com")
let networkConfig = NetworkInstrumentationConfiguration(
    ignoreURLs: .init(containing: ignoreRegex)
)

// Pass it during agent installation
try SplunkRum.install(
    with: agentConfig,
    moduleConfigurations: [networkConfig]
)
```
