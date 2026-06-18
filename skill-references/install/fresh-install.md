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

- Platform note only when non-iOS targets or a no-iOS app shape are relevant.
- Product choice: `SplunkAgent` or `SplunkAgentObjC`.
- Lifecycle insertion point and why it is minimal.
- Configuration source and missing user values.

## Platform

Target normal iOS/iPadOS apps for full RUM telemetry. Do not ask users to add
platform fences around Splunk RUM configuration, initialization, or public API
calls; the SDK handles non-iOS Apple runtimes internally.

If non-iOS Apple targets are relevant, verify both compile support and runtime
behavior:

- `Package.swift` declares package build platforms.
- `PlatformSupport.current.scope` decides runtime behavior.
- `.full` means the agent can initialize operational modules.
- `.compileOnly` means the API can compile and may run, but public calls are
  non-operational and telemetry should not be expected.
- `.unsupported` means the target is not supported by current source.

Current source maps normal iOS/iPadOS to `.full`, Mac Catalyst/tvOS/visionOS
and iOS apps running on Mac or Vision to `.compileOnly`, and macOS/watchOS to
`.unsupported`. On non-full scopes, `SplunkRum.install` returns the shared
non-operational instance with `.notRunning(.unsupportedPlatform)` instead of
starting telemetry.

In straightforward iOS-only integrations, platform support usually needs no
separate note. If other Apple targets are visible or the user asks, a light
informational note is enough: they should build and run without special
app-side handling, but the agent is non-operational there and telemetry should
only be expected from iOS/iPadOS.

If the Host App has no iOS/iPadOS app target at all, report that adding the SDK
will not produce RUM instrumentation for that app.

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
