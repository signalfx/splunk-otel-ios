# Session Replay

## Approval gate

Do not call `sessionReplay.start()` or equivalent ObjC APIs without explicit
user confirmation after reviewing sampling and sensitive surfaces. Before
changing sensitivity, custom IDs, rendering, or recording masks, load
`session-replay-privacy.md`. For Objective-C APIs, also load
`../objc/session-replay.md`.

Before enabling, inspect sensitive screens, WebViews and custom-rendered
content, existing masking, sampling, and storage implications. Keep start/stop
snippets out of `SKILL.md`, fresh-install defaults, and default local
signal generation.

Apply every approved privacy control needed for content that can be visible
when recording begins before calling `start()`. Configure class-level
sensitivity, rendering mode, and recording masks first. Set instance
sensitivity before the view can appear in a recording; if that cannot be
guaranteed, delay `start()` until it is configured.

## Public API boundary

Use Splunk RUM public APIs, not underlying implementation-only APIs, in
customer apps. Do not suggest recording quality, data producer hooks,
`onPublish`, or `deleteData` unless the current Splunk RUM public API exposes
the requested capability.

For Swift configuration types, verify imports. `SessionReplayConfiguration`
lives in `SplunkSessionReplayProxy`; normal app-facing recording, state,
sensitivity, custom ID, rendering, and mask APIs are reached through the
retained `SplunkRum` instance's `sessionReplay` property.

## Enablement, sampling, and endpoints

Session Replay module presence is not the same as recording. Current source can
create the module by default, but recording remains
`.notRecording(.notStarted)` until `agent.sessionReplay.start()` is called.

Use `SessionReplayConfiguration(enabled:samplingRate:)` only when the task asks
to enable, disable, or sample Session Replay:

```swift
import SplunkAgent
import SplunkSessionReplayProxy

let replayConfig = SessionReplayConfiguration(
    enabled: true,
    samplingRate: 0.25
)

let agent = try SplunkRum.install(
    with: configuration,
    moduleConfigurations: [replayConfig]
)
```

Sampling is decided once per agent lifecycle and is not re-evaluated on session
rotation. `nil` is equivalent to `1.0`; values below `0` or above `1` are
clamped. If `enabled` is `false`, `start()` does nothing. If the launch is
sampled out, state should report `.notRecording(.disabledBySampling)`.

Swift deferred endpoint setup can still leave Session Replay operational at
install. When endpoint configuration is added later with `updateEndpoint(_:)`,
cached replay chunks can flush. Do not tell Swift users Session Replay cannot be
enabled without immediate endpoint values; do report that backend confirmation
requires an endpoint and public access. Objective-C integrations must provide
the endpoint at install; see `../install/endpoint-and-runtime-state.md`.

If a custom endpoint is approved and Session Replay is enabled, a custom trace
endpoint alone is not enough for Session Replay upload. `EndpointConfiguration`
with realm builds both trace and Session Replay endpoints; custom endpoint
setup has a separate optional `sessionReplay` URL.

## Recording control and state

After approval, start and stop through the retained agent. Run both calls on the
main actor because Session Replay control uses UIKit-backed recording. If
approval or runtime configuration arrives off-main, hop to the main actor
before invoking the selected control:

```swift
Task { @MainActor in
    agent.sessionReplay.start()
}
```

Apply the same main-actor requirement to `stop()`. It is mainly for pausing
recording; app exit does not require an explicit stop call.

State API:

```swift
let status = agent.sessionReplay.state.status
let isRecording = agent.sessionReplay.state.isRecording
let renderingMode = agent.sessionReplay.state.renderingMode
let samplingRate = agent.sessionReplay.state.samplingRate
```

Known public status causes include: `.notStarted`, `.stopped`,
`.internalError`, `.swiftUIPreviewContext`, `.unsupportedPlatform`,
`.storageLimitReached`, and `.disabledBySampling`.

Do not print raw internal errors or private diagnostics while reporting state.

Do not start Session Replay during default local signal generation. Do not
attempt backend replay confirmation from non-operational platform runs.
