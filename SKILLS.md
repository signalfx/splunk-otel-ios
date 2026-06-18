# Splunk RUM iOS SDK Agent Skill

Use this skill when an AI coding agent needs to plan, review, apply, or verify
Splunk Real User Monitoring (RUM) instrumentation in an iOS application using
the `splunk-otel-ios` SDK.

The goal is a production-safe integration for customer apps. Prefer minimal,
idiomatic changes that fit the host app's lifecycle, language, dependency
manager, and release process.

## Operating Modes

Start by identifying the requested mode. If no mode is specified, default to
`plan-only`.

| Mode | Behavior |
| --- | --- |
| `plan-only` | Inspect the app and produce a concrete integration plan. Do not edit files. |
| `review` | Inspect an existing integration and report gaps, risks, stale APIs, and verification steps. |
| `apply` | Make the smallest safe integration changes, then build or explain blockers. |
| `verify` | Build, launch, generate telemetry, and confirm backend data when access is available. |

Always produce a plan before edits in `apply` mode. If the user approves a
previous plan, continue from that plan and update it when new evidence changes
the implementation.

## Safety Rules

- Never hard-code real RUM access tokens, API access tokens, org tokens, or
  customer secrets.
- Use placeholders such as `<YOUR_REALM>` and `<YOUR_RUM_ACCESS_TOKEN>` in
  committed examples.
- Prefer the host app's existing secret/configuration mechanism when applying
  changes.
- Do not log tokens, print token values, or include token values in generated
  reports.
- Do not add unrelated observability SDKs or upstream protocol exporters.
- Do not make SDK-version claims from memory. Check the current repository,
  package resolution, public docs, and public releases during execution.
- Keep initialization defensive. A telemetry setup failure must not crash the
  host app.

## Source Of Truth

Before planning or applying integration changes, read the current SDK sources
and docs relevant to the app:

- `README.md`
- `CHANGELOG.md`
- `SplunkAgent/Sources/SplunkAgent/SplunkAgent.docc/`
- `SplunkAgent/Sources/SplunkAgent/Public API/`
- `SplunkAgent/Sources/SplunkAgentObjC/`
- `dsymUploader/README.md`
- Public Splunk docs for iOS RUM installation, configuration, manual
  instrumentation, dSYM upload, and troubleshooting.

If local docs and source disagree, prefer the public API source on the target
branch and call out the doc mismatch.

## Inspection Checklist

Collect file-backed evidence for each applicable item.

### App Shape

- Workspace/project layout: `.xcodeproj`, `.xcworkspace`, `Package.swift`,
  `Package.resolved`, CocoaPods, other package metadata.
- Primary app target and bundle identifier.
- App lifecycle entry point:
  - SwiftUI `@main App`
  - `@UIApplicationDelegateAdaptor`
  - `AppDelegate`
  - `SceneDelegate`
  - Objective-C `main.m` / `UIApplicationMain`
- UI framework usage: SwiftUI, UIKit, storyboards, mixed UIKit/SwiftUI,
  Objective-C, mixed Swift/Objective-C.
- Existing configuration systems for build settings, xcconfig files,
  environment-specific values, generated config files, or secret injection.

### Existing Observability

Search for:

- `SplunkAgent`, `SplunkAgentObjC`, `SplunkOtel`, `SplunkRum`,
  `SplunkRumBuilder`, `EndpointConfiguration`, `AgentConfiguration`
- `SplunkRum.install`, `SPLKAgent installWith`
- deprecated static APIs such as `SplunkRum.reportError` or old screen-name
  helpers
- old crash setup such as `SplunkRumCrashReporting.start()`
- OpenTelemetry, Datadog, Firebase Crashlytics, Sentry, AppDynamics, or other
  SDKs that might duplicate crash, network, session replay, or interaction
  instrumentation

Recommend one clear path:

- fresh install
- review/fix current `SplunkAgent` integration
- migrate from old `SplunkOtel` / pre-2.0 APIs
- add manual instrumentation only

### Instrumentation Opportunities

Look for:

- `URLSession` usage and networking wrappers
- `WKWebView` creation and Browser RUM usage
- SwiftUI navigation stacks, sheets, tabs, and custom flows
- UIKit navigation controllers, tab bars, modals, and custom containers
- business workflows worth timing
- handled `do` / `catch` paths worth reporting
- custom user or account attributes
- sensitive UI that must be masked before Session Replay starts
- release build, archive, CI, Fastlane, GitHub Actions, Bitrise, or Xcode
  Run Script paths for dSYM upload

## Plan Output

In `plan-only` and before `apply`, return:

1. Evidence table: finding, file, line or search pattern, confidence.
2. Recommended path: fresh install, migration, review fix, or manual-only.
3. Minimal dependency changes.
4. Initialization location and why it is the safest lifecycle point.
5. Configuration values required from the user or environment.
6. Manual instrumentation recommendations.
7. dSYM upload recommendation for release builds.
8. Verification plan.
9. Success metrics and current baseline values where measurable.
10. Risks, blockers, and open questions.

## Apply Guidance

### Dependency

Use Swift Package Manager with:

```text
https://github.com/signalfx/splunk-otel-ios
```

Use the `SplunkAgent` product for Swift apps and `SplunkAgentObjC` for
Objective-C entry points. In mixed apps, prefer the product matching the file
where initialization will live.

Do not pin a version without checking the current public release and the host
app's dependency policy. If the app already pins versions, follow its existing
style.

### Swift Initialization

Install once, as early as practical, and retain the returned `SplunkRum`
instance for later module access.

```swift
import SplunkAgent

final class AppDelegate: NSObject, UIApplicationDelegate {
    private var splunkRum: SplunkRum?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        var config = AgentConfiguration(
            endpoint: EndpointConfiguration(
                realm: "<YOUR_REALM>",
                rumAccessToken: "<YOUR_RUM_ACCESS_TOKEN>"
            ),
            appName: "<YOUR_APP_NAME>",
            deploymentEnvironment: "<YOUR_ENVIRONMENT>"
        )

        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            config = config.appVersion(version)
        }

        #if DEBUG
        config = config.enableDebugLogging(true)
        #endif

        do {
            splunkRum = try SplunkRum.install(with: config)
        } catch {
            print("Unable to start Splunk RUM: \(error)")
        }

        return true
    }
}
```

For SwiftUI apps, either use an existing app delegate adaptor or create one if
that is the least disruptive lifecycle hook:

```swift
@main
struct ExampleApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

Use the host app's non-fatal logging facility instead of `print` when one is
available.

### Objective-C Initialization

Use `SplunkAgentObjC` and retain the returned `SPLKAgent`.

```objc
@import SplunkAgentObjC;

@interface AppDelegate ()
@property (nonatomic, strong, nullable) SPLKAgent *splunkRum;
@end

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    SPLKEndpointConfiguration *endpoint =
        [[SPLKEndpointConfiguration alloc] initWithRealm:@"<YOUR_REALM>"
                                          rumAccessToken:@"<YOUR_RUM_ACCESS_TOKEN>"];

    SPLKAgentConfiguration *config =
        [[SPLKAgentConfiguration alloc] initWithEndpoint:endpoint
                                                 appName:@"<YOUR_APP_NAME>"
                                   deploymentEnvironment:@"<YOUR_ENVIRONMENT>"];

    NSError *error = nil;
    self.splunkRum = [SPLKAgent installWith:config error:&error];
    if (self.splunkRum == nil) {
        NSLog(@"Unable to start Splunk RUM: %@", error);
    }

    return YES;
}
```

### Module Decisions

- App startup, app state, crash reporting, custom tracking, `URLSession`
  network instrumentation, slow/frozen frames, UI interactions, and WebView
  module availability are enabled by default unless module configuration or
  remote configuration changes them.
- Navigation automated tracking is not enabled by default. Enable it for UIKit
  view-controller transitions when appropriate:

```swift
splunkRum?.navigation.preferences.enableAutomatedTracking = true
```

- Prefer `.trackScreen("ScreenName")` in SwiftUI views and custom navigation
  flows.
- Use manual `track(screen:)` for UIKit tab changes and custom containers when
  automated tracking cannot infer business screen names.
- Use `customTracking.trackCustomEvent`, `trackError`, and `trackWorkflow` for
  business events, handled errors, and workflows. End workflow spans.
- For `WKWebView`, call `webViewNativeBridge.integrateWithBrowserRum(_:)`
  before loading web content. Only bridge pages the app controls and that are
  instrumented with Splunk Browser RUM because the bridge exposes the native
  session ID to loaded content.
- Start Session Replay only when product/privacy requirements allow it:

```swift
splunkRum?.sessionReplay.start()
```

- Mask sensitive UIKit views with `srSensitive`, SwiftUI views with
  `.sessionReplaySensitive()`, and assign stable custom IDs with
  `splunkRumId` where interaction names need to be more meaningful.

### Migration Guidance

For old `SplunkOtel` / pre-2.0 integrations:

- Replace the package product with `SplunkAgent` or `SplunkAgentObjC`.
- Replace `import SplunkOtel` with `import SplunkAgent`.
- Remove separate `SplunkOtelCrashReporting` setup and
  `SplunkRumCrashReporting.start()`; crash reporting is integrated.
- Replace `SplunkRumBuilder` with `AgentConfiguration` and
  `SplunkRum.install(with:moduleConfigurations:)`.
- Replace deprecated static APIs with module access through `SplunkRum.shared`
  or the retained agent instance.
- Clean and rebuild after package migration. Delete stale package resolution
  only when the host app's workflow allows it.

### dSYM Upload

For crash symbolication, verify release builds upload matching dSYMs. Prefer
CI/CD secret storage or secure Xcode build settings for the API access token.
Never commit API tokens.

Use this repository's `dsymUploader/upload-dsyms.sh` guidance or the current
public Splunk dSYM documentation, depending on the host app's release process.
Document whether the app has:

- dSYM generation enabled for release/archive builds
- a dSYM upload step
- secure realm and API-token injection
- a dry-run or release-only guard

## Verification

Run verification in layers. Stop and report the first hard blocker with command
output, but continue with lower-cost static checks where useful.

1. Static review: no real tokens in the diff; no stale `SplunkOtel` imports;
   no duplicate install paths.
2. Dependency resolution: package resolves and products link to the app target.
3. Build: app target builds for an iOS Simulator or the app's standard CI
   destination.
4. Launch: app starts without crashing, and debug logging confirms Splunk RUM
   initialization when debug logging is enabled.
5. Telemetry generation: exercise startup, screen tracking, a `URLSession`
   request, one custom event or handled error, and any app-specific manual
   instrumentation added by the diff.
6. Backend confirmation: confirm the session and expected signals in Splunk
   Observability Cloud. Allow for ingestion latency before declaring telemetry
   missing.
7. Crash symbolication readiness: verify dSYM upload configuration or document
   the missing release-pipeline work.

## Success Metrics

Report metrics as numeric values whenever possible. Binary gates are useful,
but pair them with counts or ratios so progress is measurable between runs.

### Final Acceptance Metrics

| Metric | Definition | Target |
| --- | --- | --- |
| Inspection coverage | Completed checklist items / applicable checklist items | `>= 0.90` |
| Evidence coverage | Plan claims with file or command evidence / total plan claims | `>= 0.90` |
| Secret safety | Count of real tokens or secrets introduced in tracked files | `0` |
| Migration completeness | Resolved stale SDK patterns / detected stale SDK patterns | `1.00` or no stale patterns |
| Build readiness | App build errors after integration | `0` |
| Runtime initialization | Successful launches with initialized agent / launches attempted | `1.00` |
| Telemetry coverage | Observed signal types / signal types selected for validation | `>= 0.80`, prefer `1.00` |
| Time to first telemetry | Minutes from test launch to first matching RUM data | `<= 5 min` |
| dSYM readiness | Release/archive paths with dSYM upload / release/archive paths found | `1.00` or documented blocker |
| Diff focus | Files changed outside the approved integration surface | `0` |

### Incremental Metrics

Use these during execution to show measurable progress:

| Stage | Metric | Continuous value to report |
| --- | --- | --- |
| Baseline inspection | Unknowns remaining | Count of unanswered app-shape/config questions |
| Baseline inspection | Existing instrumentation density | Splunk/observability references per KLOC or raw count |
| Plan | Plan completeness | Completed plan sections / required plan sections |
| Plan | Manual instrumentation opportunity score | Recommended opportunities / detected opportunities |
| Apply | Diff size | Files changed and non-comment lines changed |
| Apply | Integration focus | Integration-related changed files / total changed files |
| Apply | Secret scan result | Secret-like findings count after edits |
| Build | Error burn-down | Build errors remaining after each build attempt |
| Build | Warning delta | Warnings after integration minus baseline warnings |
| Runtime | Launch stability | Successful launches / launch attempts |
| Runtime | Initialization latency | Seconds from app launch to agent initialization log, if measurable |
| Telemetry | Signal coverage | Observed signal types / expected signal types |
| Telemetry | Ingestion latency | Minutes from exercise step to backend visibility |
| Review | Actionable findings closed | Fixed review findings / total review findings |

If a value cannot be measured, report `not measured` with the reason and the
smallest next step needed to make it measurable.

## Reference Validation Scenario: wikipedia-ios

Use `wikipedia-ios` as the primary validation app for this skill.

1. Preserve a pristine copy or branch.
2. Run `plan-only` and save the detection output, recommended path, risks, and
   baseline metrics.
3. Run `review` on the unmodified app and confirm the findings match the
   plan-only evidence.
4. Create a disposable branch.
5. Run `apply` with placeholders or the app's safe local configuration
   mechanism.
6. Confirm the generated diff is minimal, idiomatic for the app, and secret
   free.
7. Build the app or document external build blockers.
8. If safe credentials and backend access are available, launch the app,
   exercise selected flows, and record telemetry coverage plus ingestion
   latency.
9. Restore or discard the disposable branch after evidence is captured.

The validation report should include the plan, review notes, diff summary,
build result, metrics table, backend verification result if available, and any
blockers that prevented full verification.
