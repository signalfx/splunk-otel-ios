# Splunk RUM Agent for iOS

The Splunk RUM Agent for iOS is a modular Swift package for Real User Monitoring (RUM).

### Table of Contents
- [Requirements](#requirements)
- [Getting Started](#getting-started)
- [Modules Overview](#modules-overview)
- [Crash Symbolication (dSYM Upload)](#crash-symbolication-dsym-upload)
- [Advanced Configuration](#advanced-configuration)
- [Common Usage Examples](#common-usage-examples)
- [Objective-C Usage](#objective-c-usage)
- [Upgrading from a Previous Version](#upgrading-from-a-previous-version)
- [Contributing](#contributing)
- [License](#license)

## Requirements

Splunk RUM Agent for iOS supports iOS 15 and higher (including iPadOS 15 and higher)
and is link-compatible with apps targeting iOS 13 or 14, where its functionality is
limited to processing pending crash reports.

## Getting Started

### Installation

You can add Splunk RUM for iOS to your project using Swift Package Manager.

1. In Xcode, select **File > Add Package Dependencies...**
2. Enter the package URL: `https://github.com/signalfx/splunk-otel-ios`
3. Select the `SplunkAgent` package product and add it to your application target.

### Basic Configuration

In your `AppDelegate.swift` or main `@main` App file, import `SplunkAgent` and initialize it with your configuration. Retain the `SplunkRum` instance to interact with the agent's modules.

```swift
import SplunkAgent

// Define endpoint configuration
let endpointConfiguration = EndpointConfiguration(
    realm: "<YOUR_REALM>",
    rumAccessToken: "<YOUR_RUM_ACCESS_TOKEN>"
)

// Construct agent configuration
let agentConfiguration = AgentConfiguration(
    endpoint: endpointConfiguration,
    appName: "<YOUR_APP_NAME>",
    deploymentEnvironment: "<YOUR_DEPLOYMENT_ENVIRONMENT>"
)

var agent: SplunkRum?

do {
    // Install the agent
    agent = try SplunkRum.install(with: agentConfiguration)
} catch {
    print("Unable to start the Splunk agent, error: \(error)")
}

// Example: Enable automated navigation tracking
agent?.navigation.preferences.enableAutomatedTracking = true

// Example: Start session replay
agent?.sessionReplay.start()
```

## Modules Overview

The agent is composed of several modules, each responsible for a specific type of instrumentation.

| Module | Summary | Enabled by Default? |
|---|---|---|
| **App Startup Tracking** | Measures cold, warm, and hot application start times. | Yes |
| **App State** | Automatically tracks app lifecycle events (e.g., foreground, background). | Yes |
| **Crash Reporting** | Captures and reports application crashes on the next launch. | Yes |
| **Custom Tracking** | Manually track custom events, errors, and workflows. See [examples](#common-usage-examples). | Yes |
| **Navigation Tracking** | Tracks screen transitions, either automatically or manually. See [examples](#common-usage-examples). | No |
| **Network Monitoring** | Instruments `URLSession` requests and network status changes. | Yes |
| **Session Replay** | Provides a visual replay of user sessions. See [examples](#common-usage-examples). | No |
| **Slow & Frozen Frames** | Detects and reports UI frames that are slow or frozen. | Yes |
| **UI Interaction Tracking** | Automatically captures user taps on UI elements. | Yes |
| **WebView Instrumentation** | Links native RUM sessions with Browser RUM in `WKWebView`. | Yes |

## Crash Symbolication (dSYM Upload)

To get human-readable, symbolicated crash reports in Splunk RUM, you must upload your application's dSYM files. This repository includes a helper script to automate this process.

1.  **Locate the script** in your cloned repository at `dsymUploader/upload-dsyms.sh`.
2.  **Add a "Run Script" Build Phase** in Xcode to your app's target. Place it after the "Copy Bundle Resources" phase.
3.  **Add the following to the script area**, replacing the placeholder values:

```bash
# IMPORTANT: Update this path to where you've placed the script in your project.
SCRIPT_PATH="${SRCROOT}/path/to/upload-dsyms.sh"

if [[ -x "$SCRIPT_PATH" ]]; then
    echo "Running Splunk dSYM upload script..."
    "$SCRIPT_PATH" \
        --realm "YOUR_REALM" \
        --token "YOUR_API_ACCESS_TOKEN" \
        --directory "${DWARF_DSYM_FOLDER_PATH}"
else
    echo "Warning: Splunk dSYM upload script not found or not executable at: $SCRIPT_PATH"
fi
```

For detailed instructions on CI/CD integration, troubleshooting, and how to set up the variables shown in the script, please see the full documentation in [`dsymUploader/README.md`](./dsymUploader/README.md).

## Advanced Configuration

You can customize the agent's behavior at initialization.

### Module-Specific Configurations
Override default module settings by passing an array of configuration objects to the `install` method. For example, to disable Crash Reporting:

```swift
import SplunkAgent
import SplunkCrashReports

// Initialize the configuration of the Agent
let agentConfiguration = ...

// Disable configuration for crash reporting
let crashReportsConfiguration = SplunkCrashReports.CrashReportsConfiguration(
   isEnabled: false
)

// Specify crash module configuration during agent installation
_ = try? SplunkRum.install(
   with: agentConfiguration, 
   moduleConfigurations: [crashReportsConfiguration]
)
```

### Global Attributes
Add custom attributes to all telemetry data by setting `globalAttributes` on your `AgentConfiguration`.

```swift
import SplunkAgent

let agentConfiguration = AgentConfiguration(
    endpoint: endpointConfiguration,
    appName: "App Name",
    deploymentEnvironment: "dev"
)
    .enableDebugLogging(true)
    .globalAttributes(MutableAttributes(dictionary: [
        "enduser.role": .string("premium"),
        "enduser.id": .int(128762)]))

// Install the agent
_ = try? SplunkRum.install(
    with: agentConfiguration
)
```

## Common Usage Examples

Interact with agent modules using the `SplunkRum` instance you retained after installation.

### Manual Screen Navigation
Manually track screen names, which is especially useful for SwiftUI applications.

```swift
import SplunkAgent

let agent: SplunkRum? = ...

agent?.navigation.track(screen: "A screen")
```

### Custom Event Reporting
Track business-specific events with custom attributes.

```swift
import SplunkAgent

let agent: SplunkRum? = ...

agent?.customTracking.trackCustomEvent(
    "Completed Tax Filing",
    MutableAttributes(dictionary: [
        "Account Type": .string("Premium"),
        "Referral Source": .string("Google Ads"),
        "Filing year": .int(2025)
    ])
)
```

### Error Reporting
Manually report handled errors or exceptions.

```swift
do {
    try performRiskyOperation()
} catch let error {
    agent?.customTracking.trackError(error)
}
```

### Session Replay Privacy (Masking)
Protect user privacy by masking sensitive views from session recordings.

**UIKit:**
```swift
let sensitiveLabel = UILabel()
sensitiveLabel.srSensitive = true
```

**SwiftUI:**
```swift
Text("Card Number: XXXX-XXXX-XXXX-1234")
    .sessionReplaySensitive()
```

## Objective-C Usage

This SDK provides full support for Objective-C. For projects that use Objective-C, you need to import the optimized API with `@import SplunkAgentObjC;` instead of the default API for Swift projects. 

This API is better suited for an Objective-C project with the same functionality as its Swift counterpart.

```objc
@import SplunkAgentObjC;

// Define endpoint configuration
SPLKEndpointConfiguration* endpointConfiguration = [[SPLKEndpointConfiguration alloc] initWithRealm:@"<YOUR_REALM>" rumAccessToken:@"<YOUR_RUM_ACCESS_TOKEN>"];

// Construct agent configuration
SPLKAgentConfiguration* agentConfiguration = [[SPLKAgentConfiguration alloc] initWithEndpoint:endpointConfiguration appName:@"<YOUR_APP_NAME>" deploymentEnvironment:@"<YOUR_DEPLOYMENT_ENVIRONMENT>"];
    
NSError* error = nil;

// Install the agent
SPLKAgent* agent = [SPLKAgent installWith:agentConfiguration error:&error];

if (agent == nil) {
    NSLog(@"Unable to start the Splunk agent, error: %@", [error description]);
} else {
    // Example: Start session replay
    [[agent sessionReplay] start];
}
```

## Upgrading from a Previous Version

The most significant change in version 2.0.0 is the renaming of the Swift Package from `SplunkOtel` to `SplunkAgent`. If you are upgrading from a 0.x version, you must perform the following steps to get your project building again:

1.  **Update Swift Package Dependency:** In Xcode, update your package dependency to use version `2.0.0` or higher.
2.  **Update Target Library:** In your target's "General" -> "Frameworks, Libraries, and Embedded Content" section, remove the old `SplunkOtel` library and add the new `SplunkAgent` library.
3.  **Update Import Statements:** In your source code, replace all instances of `import SplunkOtel` with `import SplunkAgent`.
4.  **Update Crash Reporting:**
    *   Remove the separate `SplunkOtelCrashReporting` package dependency if it exists.
    *   Remove any code that calls `SplunkRumCrashReporting.start()`. Crash reporting is now an integrated module, enabled by default.
5.  **Clean and Rebuild:** It is highly recommended to clean your build folder (`Product -> Clean Build Folder`) and delete `Package.resolved` from your project workspace to avoid caching issues.

Your existing initialization code will continue to work due to backward compatibility.

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md) for instructions on building, running tests, etc.

## License

This library is licensed under the terms of the Apache Software License version 2.0.
See [the license file](./LICENSE) for more details.

> :information_source: SignalFx was acquired by Splunk in October 2019. See [Splunk SignalFx](https://www.splunk.com/en_us/investor-relations/acquisitions/signalfx.html) for more information.
