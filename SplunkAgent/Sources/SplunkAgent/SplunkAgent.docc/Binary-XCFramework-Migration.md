# Binary XCFramework Migration

Binary releases ship five xcframeworks:

- `SplunkAgent.xcframework`
- `SplunkAgentObjC.xcframework`
- `OpenTelemetryApi.xcframework`
- `OpenTelemetrySdk.xcframework`
- `CrashReporter.xcframework`

Internal `Splunk*` instrumentation modules and `Cisco*` Session Replay modules are statically linked into `SplunkAgent.xcframework`. Do not add or import those frameworks in binary integrations.

## Swift Imports

Use only `import SplunkAgent` for SDK setup and module configuration.

```swift
import SplunkAgent

let endpoint = EndpointConfiguration(
    realm: "us0",
    rumAccessToken: "<your-rum-token>"
)

let agentConfiguration = AgentConfiguration(
    endpoint: endpoint,
    appName: "MyApp",
    deploymentEnvironment: "production"
)

let networkConfig = NetworkInstrumentationConfiguration(
    ignoreURLs: try? IgnoreURLs(patterns: ["api\\.internal\\.com"])
)

let crashConfig = CrashReportsConfiguration(isEnabled: false)

try SplunkRum.install(
    with: agentConfiguration,
    moduleConfigurations: [networkConfig, crashConfig]
)
```

## Objective-C Imports

Objective-C applications should also link `SplunkAgentObjC.xcframework` and import the Objective-C module.

```objc
@import SplunkAgentObjC;
```

`CrashReporter.xcframework` is not available on visionOS. Do not link it for visionOS targets; crash reporting remains unavailable there.
