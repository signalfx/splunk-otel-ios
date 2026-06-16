# Splunk RUM Agent for iOS - AI Assistant Context

This repo is a modular Swift Package for the Splunk RUM iOS agent. It instruments iOS, iPadOS, tvOS, visionOS, and macCatalyst apps and sends telemetry to Splunk Observability Cloud.

## How to Use This Guide

- Treat this file as the primary agent-facing guidance for this repository. If it conflicts with `CODESTYLE.md`, `Development.md`, `CONTRIBUTING.md`, or a module-local pattern, follow the more specific guidance for the touched code and call out the conflict.
- Keep changes scoped to the user request.
- Get explicit confirmation before changing public API, dependencies, distribution metadata, privacy-sensitive telemetry, or CI workflows.
- Update this file when build, test, packaging, dependency, or review conventions change.

## Project Facts

- Swift 5.9+, SPM, minimum iOS 13.0.
- Public products: `SplunkAgent`, `SplunkAgentObjC`.
- Core dependency: `opentelemetry-swift-core` API/SDK only. Do not add upstream protocol exporters; this repo uses a custom OTLP/JSON exporter to control binary size.
- Main modules: `SplunkAgent`, `SplunkAgentObjC`, `SplunkCommon`, `SplunkOpenTelemetry`, `SplunkOpenTelemetryBackgroundExporter`, and instrumentation modules named `Splunk<Feature>`.
- Instrumentation modules conform to `Module` in `SplunkCommon/Sources/SplunkCommon/Modules/Module.swift`; infrastructure targets such as `SplunkOpenTelemetry` and `SplunkOpenTelemetryBackgroundExporter` do not.
- Public API lives in `SplunkAgent/Sources/SplunkAgent/Public API/`; stable public files use `API-1.0-*.swift`.
- Deprecated public API stays in `Public API/.../Deprecated/` with `@available(*, deprecated, message: "Use <replacement>")`.
- Public module APIs have both real proxies (`Proxies/Module/`) and no-op `*NonOperational` proxies (`Proxies/Non-Operational/` or `Proxies/NonOperational/`) for pre-install, disabled, or sampled-out states.
- The binary distribution uses `tools/xcframework/Project.swift` with library evolution enabled. Keep it in sync with `Package.swift`.

## Build, Test, and Validation Commands

- Do not use `swift test` as the default validation command for this repository. The test suite must run through the Xcode scheme because Apple-platform destinations, resources, and package wiring matter.
- Build validation:
  `xcodebuild -scheme SplunkAgent -destination "generic/platform=iOS Simulator" build`
- Test validation:
  `xcodebuild -scheme SplunkAgent -destination "OS=<installed OS>,name=<installed iPhone simulator>" test`
- The simulator OS and device name change over time. Before running tests, discover currently available scheme destinations with `xcodebuild -scheme SplunkAgent -showdestinations`, then substitute an installed iPhone simulator. Use `xcrun simctl list devices available` only as a fallback when the Xcode destination output is not enough. Example:
  `xcodebuild -scheme SplunkAgent -destination "OS=26.5,name=iPhone 17" test`
- For targeted test runs, keep the same scheme and destination and add `-only-testing:<TestBundle>/<TestClass>` or `-only-testing:<TestBundle>/<TestClass>/<testMethod>`.
- Report the exact command, destination, and result for any validation performed. If validation cannot run because no compatible simulator is installed, report the discovered destinations and the blocker.

## Implementation Defaults

- Inspect nearby code before editing and match the established module, naming, `// MARK: -`, and test-support patterns.
- For new modules, follow the existing target layout in `Package.swift` (for example `Splunk<Module>/Sources` and `Splunk<Module>/Tests`) with `Testing Support/Builders` and `Testing Support/Mocks` when that support structure is needed.
- Public API and protocols need DocC; new source files need the license header from `CODESTYLE.md`.
- SDK instrumentation must be defensive: never let telemetry collection crash the host app. Prefer no-op, drop, or internal logging over `fatalError`, `try!`, forced unwraps, or uncaught errors in production paths.
- For style-heavy, build/distribution, or contribution-process changes, read `CODESTYLE.md`, `Development.md`, or `CONTRIBUTING.md` before editing.

## Security, Privacy, and Dependency Guardrails

- Do not add new third-party runtime dependencies, new upstream OpenTelemetry exporters, or dependency-version overrides unless the user explicitly requests a dependency change and the binary-size, license, and xcframework impacts are reviewed.
- Do not hard-code or commit Splunk realms, access tokens, credentials, customer data, private repository paths, or local machine paths in source, tests, fixtures, docs, manifests, or generated files.
- Do not emit raw request or response bodies, cookies, authorization headers, credentials, or obvious PII through spans, logs, crash payloads, Session Replay metadata, or internal agent events. Reuse existing masking/redaction utilities where available.
- Treat privacy-impacting resource changes, Session Replay capture changes, crash-report changes, and telemetry attribute changes as customer-visible behavior changes.

## Telemetry Model

- Direct spans: Navigation, Network, AppStart, AppState, NetworkMonitor, SlowFrameDetector, and CustomTracking workflows use `Tracer.spanBuilder` -> `SimpleSpanProcessor` -> `OTLPBackgroundHTTPTraceExporter`.
- Log-as-span: CrashReports crash payloads, CustomTracking events/errors, Interactions, internal agent events, and agent events published through `DefaultEventManager` emit log records that `OTLPLogToSpanExporter` converts to spans and sends to the trace endpoint.
- Binary logs: Session Replay is the exception; it uses `OTLPSessionReplayEventProcessor` -> `OTLPBackgroundHTTPLogExporterBinary`.
- There is no production `BatchSpanProcessor` / `BatchLogRecordProcessor`. Record buffering is disk-backed in the background exporters.
- Uploads use `URLSessionConfiguration.background(withIdentifier:)`, not `UIApplication.beginBackgroundTask`.
- Some hardcoded strings and attribute keys already exist. New hot-path string keys should still be centralized per module instead of copied inline.

## Concurrency Rules

This repo is not migrated to Swift 6 strict concurrency. New code should reduce future migration churn.

- Prefer existing patterns: per-instance serial `DispatchQueue` with `PackageIdentifier.default(named:)`, then `NSLock` for tiny critical sections, then `actor` for new isolated state machines where `await` is natural.
- Do not introduce `.concurrent` queues, new global shared queues, `OSAllocatedUnfairLock`, or `NSRecursiveLock` unless the PR explains why existing patterns are insufficient.
- Shared mutable state must be protected by a queue, lock, or actor. Flag unsynchronized `var` state on classes reached from multiple queues.
- New `@unchecked Sendable`, `nonisolated(unsafe)`, or global mutable state requires a comment explaining the safety invariant and what would be needed to remove it under Swift 6.
- UIKit, SwiftUI view-body, `WKWebView`, and `CADisplayLink` work must run on the main actor. If static isolation is not practical, guard with `Thread.isMainThread` and hop with `Task { @MainActor in ... }`.
- Adding `Sendable`, `@MainActor`, actor isolation, or `final` to existing public types can break clients and must be reviewed as a public API change.

## Public API Rules

- Backward compatibility is the default. Breaking public API/ABI changes must be intentional, explicit in the PR description, and documented in `CHANGELOG.md`.
- Public API changes include Swift symbols, Objective-C bridge changes, default behavior changes, span/log attribute changes, retry/backoff changes, disk-cache changes, and distribution changes.
- Do not remove public API in the same PR that adds a replacement. Deprecate first with `@available`.
- New public module methods must update the real proxy, the `*NonOperational` proxy, Objective-C bridge if applicable, DocC, and tests.
- Treat Objective-C selector changes as high risk.
- Do not expose `@_spi(SplunkInternal)` or `@_spi(SplunkTesting)` to customers.

## Packaging Rules

- `Package.swift` and `tools/xcframework/Project.swift` must stay synchronized for products, targets, platforms, dependencies, resources, and module links.
- Run or request `tools/xcframework/scripts/check-manifest-sync.sh` when either manifest changes.
- Dependency bumps for `opentelemetry-swift-core` or `PLCrashReporter` must stay exact-pinned and compatible with the xcframework build pipeline.
- New SPM products are customer-visible distribution changes.
- Use `TargetWrappers/` for Cisco binary target wrappers; it is the directory referenced by `Package.swift`.
- Resource changes must be reflected in both SPM and xcframework distribution and reviewed for `PrivacyInfo.xcprivacy` impact.
- `dsymUploader/` is a standalone client integration script, not an SPM product.
- GitHub Actions must be pinned to commit SHAs, not tags.
- Session Replay dependency mode is controlled by `USE_SESSION_REPLAY_REPO`, `USE_LOCAL_SESSION_REPLAY`, `SESSION_REPLAY_BRANCH`, and `SESSION_REPLAY_LOCAL_PATH`; development plugins by `USE_DEVELOPMENT_PLUGINS`.

## PR Review Priorities

Review findings in this order. Prioritize quality and production performance over style.

### P1 - Production Performance and Host-App Safety

Block changes that can crash the host app. Block or request measurement for changes that add avoidable overhead to host apps at scale.

- Watch hot paths: span/log emission, export pipeline, swizzled `URLSession`, navigation, interactions, slow-frame detection, crashes, and Session Replay.
- Flag `try!`, forced unwraps, unchecked array/dictionary access, uncaught thrown errors, or assertions that can terminate production host apps from instrumentation paths.
- Flag per-event encoder/formatter creation, `NSError`, reflection, `String(format:)`, repeated `Bundle` / `FileManager` / `UserDefaults` reads, O(n) scans over growing collections, main-thread I/O, unbounded memory, missing observer teardown, and display-link leaks.
- Flag meaningful binary-size increases, especially dependencies that undermine the custom OTLP encoder's size-saving purpose.
- Ask for Instruments, allocation, signpost, or app-level measurement when the cost is not obvious.

### P2 - Public API and Compatibility

- Surface any removed/renamed public symbols, changed signatures, changed default values, enum case changes, Objective-C selector changes, or public behavior changes.
- Require deprecation + replacement rather than removal unless an intentional breaking release is stated.
- Require `CHANGELOG.md` for client-visible API or behavior changes.
- Ensure real and `NonOperational` proxies stay aligned.

### P3 - Concurrency and Swift 6 Readiness

- Shared mutable state must be synchronized using repo-standard queues, locks, or actors.
- New Swift concurrency escape hatches (`@unchecked Sendable`, `nonisolated(unsafe)`) must be justified.
- Public isolation changes (`@MainActor`, `Sendable`, actor conversion) are public API risks.
- Prefer changes that make Swift 6 strict-concurrency migration easier, not noisier.

### P4 - Telemetry Correctness

- New signals must explicitly choose the correct pipeline: direct span, log-as-span, or Session Replay binary log.
- Do not route non-Session-Replay data through `OTLPBackgroundHTTPLogExporter*` without a binary-body reason.
- Prefer OpenTelemetry semantic dotted attribute keys (`screen.name`, `http.method`). Keep snake_case only when matching an existing module convention.
- New span names, event names, attribute keys, header names, and error codes should be module constants, not copied inline.
- Changes to retry/backoff, disk cap, endpoint choice, or required attributes are customer-visible.

### P5 - Packaging and Distribution

- Check `Package.swift` and xcframework manifest sync.
- Check new targets, resources, products, binary wrappers, dSYM docs, and example app links.
- Check dependency pinning, licenses, transitive dependency size, and CI action SHA pinning.

### P6 - Test Value

- Prefer tests that assert emitted telemetry, state transitions, configuration effects, and failure behavior.
- Flag bare `XCTAssertNoThrow`, "not nil", or sleep-based tests when they do not prove behavior.
- Public module APIs need both operational and non-operational coverage.

### P7 - Style and Docs

- Keep changes local to established module boundaries.
- Follow SwiftFormat/SwiftLint/CODESTYLE.
- Add DocC for public API and CHANGELOG entries for client-visible changes.

## Design Assumptions to Surface in Reviews

Call these out as design choices when a PR relies on or changes them:

1. Export buffering is disk-backed, not an in-memory bounded queue.
2. Background `URLSession` scheduling, retry count, and disk caps define when data is delayed or dropped.
3. `SplunkRum.shared` and session state assume a mostly singleton, install-once lifecycle.
4. Sampling is chosen at session start; switching mid-session is a behavior/API change.

## Key Files

- `Package.swift` - SPM manifest; only `SplunkAgent` and `SplunkAgentObjC` are public products.
- `SplunkAgent/Sources/SplunkAgent/Public API/` - public Swift API.
- `SplunkAgent/Sources/SplunkAgentObjC/` - Objective-C bridge.
- `SplunkCommon/Sources/SplunkCommon/Modules/Module.swift` - module protocol.
- `SplunkOpenTelemetry/.../OTLPLogToSpanExporter.swift` - log/event to span conversion.
- `SplunkOpenTelemetryBackgroundExporter/.../BackgroundHTTPClient.swift` - background upload and disk queue.
- `SplunkOpenTelemetryBackgroundExporter/.../OTLPEncoder/` - custom OTLP/JSON encoder.
- `tools/xcframework/Project.swift` - binary distribution manifest.
- `tools/xcframework/scripts/check-manifest-sync.sh` - manifest drift check.
- `TargetWrappers/` - Cisco binary target wrappers.
- `dsymUploader/` - dSYM upload helper for clients.
- `CHANGELOG.md`, `CODESTYLE.md`, `Development.md`, `CONTRIBUTING.md`.
