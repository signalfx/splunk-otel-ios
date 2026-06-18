# Fresh Install

## Load when

Load for new Splunk RUM integration, dependency/product selection, platform
checks, lifecycle entry-point decisions, or core configuration.

## Do not load when

Do not load for migration-only review unless a fresh install path is also under
consideration.

## Source files to verify

- Host App project/package files
- lifecycle files: Swift `App`, `AppDelegate`, `SceneDelegate`, `main.m`
- `Package.swift`
- `README.md`
- `SplunkAgent/Sources/SplunkAgent/Public API/SplunkRum.swift`
- `SplunkAgent/Sources/SplunkAgent/Public API/API-1.0-AgentConfiguration.swift`
- platform support files under `SplunkAgent/Sources/SplunkAgent/Utils/Platform Support/`

## Required output additions

- Target platform support decision.
- Product choice: `SplunkAgent` or `SplunkAgentObjC`.
- Lifecycle insertion point and why it is minimal.
- Configuration source and missing user values.

## Platform

Target normal iOS/iPadOS apps. Refuse macOS/watchOS and treat Mac Catalyst,
tvOS, and visionOS as compile-only unless current source proves full runtime
support.

## Dependency and product

Use SPM package:

```text
https://github.com/signalfx/splunk-otel-ios
```

Use `SplunkAgent` for Swift integration files. Use `SplunkAgentObjC` when the
initialization file is Objective-C. In mixed apps, choose by the file that owns
initialization; do not add a Swift wrapper just to initialize an Objective-C app.

Do not pin a version from memory. Check current public releases and the Host
App dependency policy.

## Lifecycle decision tree

- SwiftUI without `AppDelegate`: prefer existing `@main App.init` when that is
  the smallest hook.
- SwiftUI with app delegate adaptor: use the existing delegate if present.
- UIKit code-only or storyboard apps: prefer existing `AppDelegate`.
- `SceneDelegate`: use for scene-specific/manual instrumentation, not default
  SDK install, unless the app already centralizes startup there.
- Objective-C: use existing ObjC app delegate and `SplunkAgentObjC`.

## Safe Swift initialization pattern

Use placeholders or deferred endpoint. Do not log raw errors.

```swift
import SplunkAgent

private var splunkRum: SplunkRum?

func startSplunkRum() {
    let config = AgentConfiguration(
        appName: "<YOUR_APP_NAME>",
        deploymentEnvironment: "<YOUR_ENVIRONMENT>"
    )

    do {
        splunkRum = try SplunkRum.install(with: config)
    } catch {
        // Non-fatal. Do not print the raw error; it may contain config values.
    }
}
```

Add endpoint configuration only when the user approves the Host App's safe
secret/configuration mechanism.

