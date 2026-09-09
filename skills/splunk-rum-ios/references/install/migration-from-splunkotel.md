# Migration From SplunkOtel

## Detector groups

Search for:

```text
SplunkOtel SplunkOtelCrashReporting import SplunkOtel @import SplunkOtel
SplunkRum.initialize SplunkRumBuilder beaconUrl: rumAuth: .build()
SplunkRumCrashReporting.start
SplunkRum.reportError SplunkRum.reportEvent SplunkRum.setScreenName
SplunkRum.getSessionId SplunkRum.isInitialized SplunkRum.debugLog
setLocation spanDiskCacheMaxSize setSpanSchedulingDelay allowInsecureBeacon
bspScheduleDelay SplunkRum.integrateWithBrowserRum
```

## Workflow

1. Classify findings as direct replacement, behavior-preserving rewrite, or
   no-equivalent/manual review.
2. Replace package/import/product names with `SplunkAgent` or
   `SplunkAgentObjC`.
3. Replace `SplunkRumBuilder` with `AgentConfiguration` plus
   `SplunkRum.install(with:moduleConfigurations:)`.
4. Replace deprecated static APIs with retained agent or `SplunkRum.shared`
   module access.
5. Remove separate old crash setup; crash reporting is integrated.
6. Load feature references only for stale APIs that appear.

Source-backed call-compatible rewrites:

- `SplunkRum.getSessionId()` -> `SplunkRum.shared.session.state.id`
- `SplunkRum.isInitialized()` ->
  `SplunkRum.shared.state.status == .running`
- `SplunkRum.setGlobalAttributes(legacyAttributes)` -> convert the legacy
  values to `MutableAttributes`, then call
  `SplunkRum.shared.globalAttributes.addDictionary(attributes.getAll())`
- `SplunkRum.removeGlobalAttribute(key)` ->
  `SplunkRum.shared.globalAttributes.remove(for: key)`
- `SplunkRum.reportError(...)` -> the matching
  `SplunkRum.shared.customTracking.trackError(_:)` or `trackException(_:)`
- `SplunkRum.reportEvent(name:attributes:)` -> convert the legacy attributes to
  `MutableAttributes`, then call
  `SplunkRum.shared.customTracking.trackCustomEvent(name, attributes)`
- `SplunkRum.setScreenName(name)` ->
  `SplunkRum.shared.navigation.track(screen: name)`

Manual-review or no-effect legacy calls:

- `SplunkRum.debugLog` is a no-op in current deprecated source.
- `enableDiskCache(enabled:)` is a no-op in current builder source.
- slow/frozen frame threshold builder methods are discontinued and ignored.
- `allowInsecureBeacon`, scheduling-delay, and disk-cache sizing need source
  verification before proposing any replacement.

Do not introduce Session Replay, WebView bridging, header capture, endpoint
changes, or dSYM upload during migration unless the user explicitly approves.
