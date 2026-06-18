# Sample App Workflow

## Load when

Load when the user asks to create or review a sample app, demo app, or minimal
integration example.

## Do not load when

Do not load for production Host App integration unless the user asks for a
separate sample.

## Source files to verify

- `Package.swift`
- `README.md`
- `SplunkAgent/Sources/SplunkAgent/SplunkAgent.docc/Getting-Started.md`
- `Applications/AgentTestApp/`

## Required output additions

- Sample purpose and app shape.
- Features demonstrated.
- Features intentionally omitted or gated.
- How to run and verify without secrets.

## Guidance

Do not copy SDK demo defaults into customer guidance. Demo apps may contain
debug logging, demo token strings, Session Replay start, global attributes, or
header capture. Treat those as SDK exercise code, not production defaults.

A safe sample should demonstrate:

- SPM dependency and product selection
- retained agent instance
- app name and deployment environment
- deferred endpoint by default
- optional placeholder endpoint configuration only when requested
- one SwiftUI or UIKit screen event
- one benign `URLSession` request
- one custom event or handled error
- local build/launch verification

Do not enable Session Replay, WebView bridging, network header capture, dSYM
upload, or custom endpoint URLs in the default sample. Offer them as opt-in
extensions with explicit warnings.

