# Workflow

Load for every task using this Skill Bundle.

## Procedure

1. Identify the requested mode and instrumentation depth. Default to
   `plan` / `review` mode and `baseline` depth.
2. Inspect before deciding. Do not assume app lifecycle, language, platform, or
   dependency manager.
3. Check Host App version-control state before `apply`. If dirty, report branch
   and changed files and require explicit confirmation.
4. Load only the topic references needed by Host App evidence.
5. Produce a plan before edits. Update the plan if new evidence changes the
   safest integration point.
6. Keep edits scoped to Splunk RUM dependency/linkage, initialization, explicit
   instrumentation, and approved release/build-phase work.
7. Verify in layers: static review, dependency resolution, build, launch, safe
   signal exercise, backend only when user-provided public access is available.

## Current-source rule

Do not rely on memory for SDK version, module defaults, or API syntax. Check the
current local source and public release/docs when the answer depends on current
state. If docs disagree with public API source, prefer source and report the
mismatch.

## Instrumentation depth

Depth controls breadth, not safety. It does not override approval gates,
privacy rules, app ownership boundaries, or the requirement to inspect first.

- `baseline`: dependency/linkage, initialization, default operational
  modules, and only the smallest explicit instrumentation needed for the user's
  stated goal.
- `targeted`: baseline plus approved additions for app surfaces found during
  inspection, such as primary screens, sensitive URL exclusions, selected
  business events, or one approved WebView bridge.
- `comprehensive`: broad inspected coverage across applicable instrumentation
  topics: screen coverage, network policy, custom events/errors/workflows,
  attributes, Session Replay, WebViews, dSYM readiness, and verification. Apply
  only the portions the user approves.

When the user asks for complete instrumentation, translate that to
`comprehensive` planning with explicit choices and checkpoints. Do not enable
every available feature without inspection and approval.

## Inspection checklist

Inspect the Host App before deciding on any integration path:

- dependency manager and project type
- hybrid framework evidence: React Native, Flutter, generated `ios/`
  wrapper, or product-specific Splunk hybrid SDK package
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

Source files to inspect:

- `.xcodeproj`, `.xcworkspace`, `Package.swift`, `Package.resolved`
- `Podfile`, `Cartfile`, generated project manifests, CI files
- `package.json`, `pubspec.yaml`
- `AppDelegate.*`, `SceneDelegate.*`, Swift `@main App`, `main.m`
- storyboards, SwiftUI views, UIKit controllers, networking wrappers
- `SplunkAgent/Sources/SplunkAgent/Public API/`
- `SplunkAgent/Sources/SplunkAgentObjC/`
- `SplunkAgent/Sources/SplunkAgent/Utils/Platform Support/`

Search terms for existing instrumentation:

```text
SplunkAgent SplunkAgentObjC SplunkOtel SplunkRum SplunkRumBuilder
SplunkRum.install SPLKAgent installWith EndpointConfiguration AgentConfiguration
SplunkRumCrashReporting OpenTelemetry Datadog Crashlytics Sentry AppDynamics
URLSession WKWebView trackScreen reportError reportEvent setScreenName
@splunk/otel-react-native splunk_otel_flutter react-native flutter
```

## Safety rules

- Never introduce, copy, persist, print, or reproduce secrets.
- Never print raw SDK errors, `localizedDescription`, endpoint/configuration
  descriptions, request descriptors, headers, payloads, cookies, tokens, or
  token-like values. Current `AgentConfigurationError` descriptions can include
  supplied endpoint or token values — do not copy public-doc examples that print
  raw errors.
- Use placeholders in examples and the Host App's existing secret/configuration
  mechanism in code.
- Redact paths or identifiers when they include customer-private data.
- Do not enable high-risk features without explicit user approval.

High-risk features requiring approval:

- Session Replay start or masking changes
- WebView Browser RUM bridge
- captured request or response headers
- endpoint update or custom endpoint URL
- dSYM upload and API-token handling
- CI workflow, Xcode build phase, or Xcode build setting changes

Reject obvious sensitive header capture:

```text
Authorization Cookie Set-Cookie X-SF-Token X-API-Key API-Key Session-Token
```

Before network changes, report that URL path/query can be captured and propose
`ignoreURLs` or span redaction for sensitive routes.

## Required output

For `plan` / pre-`apply`, report:

1. Evidence table with file paths, line numbers or search patterns, and confidence.
2. Recommended path: fresh install, migration, review fix, manual-only, sample,
   product-specific hybrid SDK referral, non-operational platform note, or
   no-iOS-target outcome.
3. References loaded and why.
4. Minimal dependency, linkage, lifecycle, and configuration changes.
5. Required user-provided values or approvals.
6. Verification plan and measurable baseline metrics.
7. Risks, blockers, and open questions.

For `apply`, keep diffs scoped to explicit Splunk RUM instrumentation, required
package/linkage, and approved release/build-phase work.

For `verify`, report build result, launch result, exercised safe signals,
credential status, backend observations if available, redacted evidence, and
remaining blockers.
