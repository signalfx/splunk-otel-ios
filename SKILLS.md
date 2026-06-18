# Splunk RUM iOS SDK Agent Skill

Use this skill when a coding agent must plan, review, apply, or verify Splunk
Real User Monitoring instrumentation in a customer iOS app using this SDK.

The Skill Bundle is public-release safe. Keep `SKILLS.md` as a router: load
only the `skill-references/` files needed for the Host App and requested mode.

## Modes

If the user does not specify a mode, default to `plan` / `review` and do not
edit files.

| Mode | Behavior |
| --- | --- |
| `plan` | Inspect the Host App and produce an evidence-backed integration plan. |
| `review` | Inspect an existing setup and report gaps, risks, stale APIs, and verification steps. |
| `apply` | Make only approved Splunk RUM instrumentation changes, then verify or report blockers. |
| `verify` | Build, launch, exercise safe signals, and confirm telemetry when user-provided access is available. |
| `sample` | Create or review a small sample app that demonstrates safe basic features. |

Before `apply`, check version-control state. If the Host App worktree is dirty,
report branch and changed files and require explicit confirmation to proceed.
If no version control is present, recommend creating a checkpoint before edits.

## Hard Gates

- Do not introduce, copy, persist, print, or reproduce secrets.
- Do not print raw SDK errors, `localizedDescription`, endpoint/configuration
  descriptions, headers, request descriptors, payloads, or token-like values.
- Do not change app architecture. Add lifecycle wrappers only when inspection
  shows they are the smallest safe integration point.
- If the Host App uses a hybrid SDK such as React Native or Flutter, do not
  directly instrument generated native iOS project files by default. Route setup
  to the product-specific hybrid SDK; use this Skill Bundle only for explicit
  narrow native iOS subtopics.
- Do not add app-side platform fences for Splunk RUM public API calls. If
  non-iOS Apple targets are relevant, note that the SDK can build and run there
  in a lightweight non-operational mode; RUM telemetry is expected on iOS/iPadOS.
- Do not add endpoint URLs by default. Prefer deferred endpoint setup or the
  Host App's existing configuration mechanism.
- Gate Session Replay, WebView bridging, network header capture, endpoint
  updates, dSYM upload, CI edits, and Xcode build-phase/build-setting changes
  behind explicit user approval.
- Keep telemetry setup non-fatal for the Host App.
- Do not use Splunk-internal systems or private workflows in Runtime Skill
  output. Backend verification requires user-provided public Splunk access.

## Source Of Truth

Check current local source, docs, and public releases during execution. Prefer
public API source over stale docs when they disagree and report the mismatch.

Start with:

- `README.md`
- `CHANGELOG.md`
- `Package.swift`
- `SplunkAgent/Sources/SplunkAgent/SplunkAgent.docc/`
- `SplunkAgent/Sources/SplunkAgent/Public API/`
- `SplunkAgent/Sources/SplunkAgentObjC/`
- `SplunkAgent/Sources/SplunkAgent/Utils/Platform Support/`
- `dsymUploader/README.md`
- current public Splunk iOS RUM docs and public GitHub releases when version or
  installation guidance matters

## Always Load

- [`skill-references/workflow.md`](skill-references/workflow.md)
- [`skill-references/inspection.md`](skill-references/inspection.md)
- [`skill-references/privacy-and-security.md`](skill-references/privacy-and-security.md)
- [`skill-references/metrics-and-reporting.md`](skill-references/metrics-and-reporting.md)

## Load Rules

| Task or evidence | Load these files |
| --- | --- |
| React Native, Flutter, `package.json`, `pubspec.yaml`, generated `ios/` wrapper | [`install/hybrid-apps.md`](skill-references/install/hybrid-apps.md) |
| Fresh install, product choice, lifecycle entry point, SwiftUI/UIKit/AppDelegate/no-AppDelegate cases | [`install/fresh-install.md`](skill-references/install/fresh-install.md) |
| Build/link/package failures, product mismatch, stale package metadata | [`install/build-and-link-errors.md`](skill-references/install/build-and-link-errors.md) |
| Deferred endpoint, endpoint update/disable, runtime state, sampling, duplicate install | [`install/endpoint-and-runtime-state.md`](skill-references/install/endpoint-and-runtime-state.md) |
| `SplunkOtel`, `SplunkRumBuilder`, deprecated static APIs, old crash setup | [`install/migration-from-splunkotel.md`](skill-references/install/migration-from-splunkotel.md) |
| Default SDK modules, app start/state, crash runtime behavior, slow/frozen frames, interactions | [`instrumentation/default-modules.md`](skill-references/instrumentation/default-modules.md) |
| Custom events, handled errors, workflows, user/session/global attributes | [`instrumentation/custom-tracking-and-attributes.md`](skill-references/instrumentation/custom-tracking-and-attributes.md) |
| SwiftUI/UIKit screen tracking, tabs, navigation stacks, storyboards, custom containers | [`instrumentation/navigation.md`](skill-references/instrumentation/navigation.md) |
| `URLSession`, URL exclusions, trace headers, captured headers | [`instrumentation/network.md`](skill-references/instrumentation/network.md) |
| Session Replay, masking, sensitivity, sampling, recording state | [`instrumentation/session-replay.md`](skill-references/instrumentation/session-replay.md) |
| `WKWebView`, Browser RUM bridge, native session bridge exposure | [`instrumentation/webview.md`](skill-references/instrumentation/webview.md) |
| Objective-C or mixed app product/lifecycle decisions | [`objc/product-and-lifecycle.md`](skill-references/objc/product-and-lifecycle.md) |
| Objective-C UIKit/storyboard/navigation details | [`objc/uikit-storyboards-navigation.md`](skill-references/objc/uikit-storyboards-navigation.md) |
| Objective-C module configuration examples | [`objc/module-configuration.md`](skill-references/objc/module-configuration.md) |
| dSYM upload, crash symbolication, archive/release/CI changes | [`release/crash-and-dsym.md`](skill-references/release/crash-and-dsym.md) |
| Local build and launch verification | [`verification/local-build-and-launch.md`](skill-references/verification/local-build-and-launch.md) |
| No-credential signal exercise and pending-artifact checks | [`verification/local-signal-generation.md`](skill-references/verification/local-signal-generation.md) |
| Backend telemetry confirmation with user-provided public Splunk access | [`verification/backend-telemetry.md`](skill-references/verification/backend-telemetry.md) |
| Objective-C and mixed-app validation scenarios | [`verification/objc-and-mixed-apps.md`](skill-references/verification/objc-and-mixed-apps.md) |
| Common failures, no telemetry, non-iOS target behavior, duplicate install, endpoint, network, Session Replay, WebView, dSYM symptoms | [`verification/troubleshooting.md`](skill-references/verification/troubleshooting.md) |
| User asks to create a sample app or demo | [`sample-app-workflow.md`](skill-references/sample-app-workflow.md) |

## Output Requirements

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
package/linkage, and approved release/build-phase work. Do not rewrite unrelated
app architecture or configuration.

For `verify`, report build result, launch result, exercised safe signals,
credential status, backend observations if available, redacted evidence, and
remaining blockers.
