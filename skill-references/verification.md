# Verification

## Layers

Work through these in order. Stop and report blockers; continue lower-cost
static checks when useful.

1. Static review
2. Dependency resolution
3. Build
4. Launch
5. Safe local signal exercise
6. Backend — only with user-provided public Splunk access

Deferred setup needs no credentials to build. A launch still persists telemetry;
use an approved non-production endpoint or delete the disposable simulator
installation before configuring a real endpoint.

## Build and launch

Use the Host App's established build path. Prefer simulator destinations already
used by the project or CI.

A build or launch on a compile-only or non-operational platform is valid
build/run evidence but not telemetry verification. RUM signal verification
requires an iOS/iPadOS runtime.

## Safe local signal exercise

Run only for an operational agent with an approved non-production endpoint.
Report `.notRunning(.unsupportedPlatform)` or `.notRunning(.sampledOut)`
instead.

Exercise only:

- app start and launch
- one screen/navigation event
- one benign `URLSession` request
- one custom event or handled error

Do not print telemetry payloads, request descriptors, headers, endpoint values,
or stored payload contents. Report pending-artifact counts by signal type only.
Do not start Session Replay or bridge WebViews as part of signal exercise.

## Backend telemetry

Load when the user asks to confirm data in Splunk Observability Cloud and has
provided safe public Splunk access.

Do not use internal Splunk systems, private realms, private query scripts, or
private backend workflows.

If access is available, confirm: session or app launch visibility, selected
screen/navigation signal, selected network signal, selected custom event/error
signal. Allow ingestion latency before declaring telemetry missing. Report
timestamps, signal types, and redacted identifiers only.

Do not attempt backend confirmation from non-operational platform runs.

## Objective-C and mixed app verification

Cover the scenario that matches the Host App: code-only ObjC, storyboard ObjC,
mixed app with Swift-owned init, mixed app with ObjC-owned init, or Swift app
calling into ObjC helpers.

Verify no Swift-only APIs were inserted into `.m` files. Verify ObjC snippets
compile against bridged API selectors.

## Troubleshooting

Symptom router:

- **Build/link failure**: load `install/build-and-link-errors.md`.
- **No telemetry**: check platform, install status, sampling, endpoint, module
  enablement, network exclusions, selected signal type.
- **Non-iOS Apple target**: load `install/fresh-install.md`; do not add
  app-side platform fences; note non-operational RUM behavior only when relevant.
- **Duplicate install**: load `install/endpoint-and-runtime-state.md`; inspect
  call sites and explain current SDK behavior.
- **Endpoint/deferred endpoint**: load `install/endpoint-and-runtime-state.md`.
- **Network issue**: load `instrumentation/network.md`.
- **Session Replay issue**: load `instrumentation/session-replay.md`.
- **WebView issue**: load `instrumentation/webview.md`.
- **dSYM issue**: load `release/crash-and-dsym.md`.
- **Stale API**: load `install/migration-from-splunkotel.md`.

Prefer runtime status and public API state over raw error text. Never ask the
user to paste unredacted tokens, endpoint config, headers, payloads, or raw SDK
error descriptions.
