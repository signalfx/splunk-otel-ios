# Troubleshooting

## Load when

Load for build failures, app launch failures, no telemetry, non-iOS target
behavior, duplicate installs, endpoint issues, network gaps, Session Replay,
WebView, dSYM, or migration symptoms.

## Do not load when

Do not load for a clean fresh-install plan with no failure symptoms.

## Source files to verify

- relevant Host App files for the symptom
- `Package.swift`, public API source, platform support source
- feature-specific references matching the symptom
- `dsymUploader/README.md` for dSYM symptoms

## Required output additions

- Symptom branch.
- Evidence inspected.
- Likely cause and confidence.
- Safe next action.
- Redacted values encountered.

## Symptom router

- Build/link failure: load `install/build-and-link-errors.md`.
- No telemetry: check platform, install status, sampling, endpoint, module
  enablement, network exclusions, selected signal type.
- Non-iOS Apple target noticed: load `install/fresh-install.md`; do not tell
  the user it cannot build or run, do not add app-side platform fences, and
  only note non-operational RUM behavior when it matters to the symptom.
- Duplicate install: load `install/endpoint-and-runtime-state.md`; inspect call
  sites and explain current SDK behavior.
- Endpoint/deferred endpoint: load `install/endpoint-and-runtime-state.md`.
- Network issue: load `instrumentation/network.md`.
- Session Replay issue: load `instrumentation/session-replay.md`.
- WebView issue: load `instrumentation/webview.md`.
- dSYM issue: load `release/crash-and-dsym.md`.
- Stale API: load `install/migration-from-splunkotel.md`.

Prefer runtime status and public API state over raw error text. Never ask the
user to paste unredacted tokens, endpoint config, headers, payloads, or raw SDK
error descriptions.
