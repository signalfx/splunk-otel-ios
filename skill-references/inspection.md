# Inspection

## Load when

Load for every `plan`, `review`, `apply`, or `verify` task.

## Do not load when

Do not load for a pure sample-app request unless the sample must mimic an
existing app.

## Source files to verify

Host App:

- `.xcodeproj`, `.xcworkspace`, `Package.swift`, `Package.resolved`
- `Podfile`, `Cartfile`, generated project manifests, CI files
- `AppDelegate.*`, `SceneDelegate.*`, Swift `@main App`, `main.m`
- storyboards, SwiftUI views, UIKit controllers, networking wrappers

SDK:

- `Package.swift`
- `SplunkAgent/Sources/SplunkAgent/Public API/`
- `SplunkAgent/Sources/SplunkAgentObjC/`
- `SplunkAgent/Sources/SplunkAgent/Utils/Platform Support/`

## Required output additions

- App-shape table: evidence, path, confidence.
- Recommended path: fresh install, migration, review fix, manual-only, sample,
  non-operational platform note, or no-iOS-target outcome.
- Unknowns remaining.

## Checklist

Inspect:

- dependency manager and project type
- primary app target and platform destinations
- Swift, Objective-C, or mixed language boundaries
- lifecycle: SwiftUI `App.init`, app delegate adaptor, Swift/ObjC
  `AppDelegate`, `SceneDelegate`, storyboards, `main.m`, no-AppDelegate cases
- existing configuration and secret-injection mechanism
- existing observability SDKs or duplicate instrumentation risk
- network layer and `URLSession` usage
- `WKWebView` usage and whether web content is app-controlled
- navigation: SwiftUI stacks/tabs/sheets, UIKit nav controllers, tab bars,
  modals, custom containers, storyboards
- sensitive UI that would need Session Replay masking
- release/archive/CI paths for dSYM upload

Search terms:

```text
SplunkAgent SplunkAgentObjC SplunkOtel SplunkRum SplunkRumBuilder
SplunkRum.install SPLKAgent installWith EndpointConfiguration AgentConfiguration
SplunkRumCrashReporting OpenTelemetry Datadog Crashlytics Sentry AppDynamics
URLSession WKWebView trackScreen reportError reportEvent setScreenName
```
