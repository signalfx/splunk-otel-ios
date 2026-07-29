# Session Replay

## Approval gate

Do not call `sessionReplay.start()` or equivalent ObjC APIs without explicit
user confirmation after reviewing sampling and sensitive surfaces. Before
changing sensitivity, custom IDs, rendering, or recording masks, load
`session-replay-privacy.md`. For Objective-C APIs, also load
`../objc/session-replay.md`.

Before enabling, inspect sensitive screens, WebViews and custom-rendered
content, existing masking, sampling, and storage implications. Keep start/stop
snippets out of top-level `SKILLS.md`, fresh-install defaults, and default local
signal generation.

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
rotation. `nil` means equivalent to `1.0`; values outside `<0, 1>` are clamped.
If `enabled` is `false`, `start()` does nothing. If the launch is sampled out,
state should report `.notRecording(.disabledBySampling)`.

Deferred endpoint setup can still leave Session Replay operational at install.
When endpoint configuration is added later with `updateEndpoint(_:)`, cached
replay chunks can flush. Do not tell users Session Replay cannot be enabled
without immediate endpoint values; do report that backend confirmation requires
an endpoint and public access.

If a custom endpoint is approved and Session Replay is enabled, a custom trace
endpoint alone is not enough for Session Replay upload. `EndpointConfiguration`
with realm builds both trace and Session Replay endpoints; custom endpoint
setup has a separate optional `sessionReplay` URL.

## Recording control and state

After approval, start and stop through the retained agent:

```swift
agent.sessionReplay.start()
agent.sessionReplay.stop()
```

`stop()` is mainly for pausing recording; app exit does not require an explicit
stop call.

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
