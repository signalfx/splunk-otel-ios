# Objective-C Module Configuration

## Load when

Load when configuring SDK modules from Objective-C or mixed apps.

## Do not load when

Do not load for pure Swift module configuration.

## Source files to verify

- `SplunkAgent/Sources/SplunkAgentObjC/Modules/`
- `SplunkAgent/Sources/SplunkAgentObjC/Model Conversions/`
- Swift public API equivalents for source-of-truth comparison

## Required output additions

- ObjC module APIs verified.
- Swift-only APIs avoided.
- Safety gates for high-risk module changes.

## Guidance

Verify each ObjC configuration class before writing snippets. Module coverage
exists for navigation, network, crash reports, interactions, slow frames,
Session Replay, and WebView, but not every Swift convenience API has an ObjC
equivalent.

High-risk module changes still require feature references:

- network header capture: `instrumentation/network.md`
- Session Replay start/masking: `instrumentation/session-replay.md`
- WebView bridge: `instrumentation/webview.md`
- dSYM upload: `release/crash-and-dsym.md`

Do not force Swift-only workflow APIs into Objective-C plans.

