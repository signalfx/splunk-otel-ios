# Objective-C Module Configuration

Load when configuring SDK modules from Objective-C or mixed apps.

## Guidance

Verify each ObjC configuration class before writing snippets. Module coverage
exists for navigation, network, crash reports, interactions, slow frames,
Session Replay, and WebView, but not every Swift convenience API has an ObjC
equivalent.

Verified configuration classes:

- `SPLKNavigationConfiguration`
- `SPLKNetworkInstrumentationConfiguration`
- `SPLKCrashReportsConfiguration`
- `SPLKInteractionsConfiguration`
- `SPLKSlowFrameDetectorConfiguration`
- `SPLKSessionReplayConfiguration`

Use `SPLKModuleConfiguration` subclasses in the
`[SPLKAgent installWith:moduleConfigurations:error:]` overload. Do not use
Swift module configuration structs in `.m` files.

High-risk module changes still require the relevant feature reference:

- network header capture: `instrumentation/network.md`
- Session Replay start/masking: `instrumentation/session-replay.md`
- WebView bridge: `instrumentation/webview.md`
- dSYM upload: `release/crash-and-dsym.md`
