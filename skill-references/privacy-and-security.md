# Privacy And Security

## Load when

Load for every task. This is the safety hub for Runtime Agent behavior.

## Do not load when

Do not skip for any Host App task.

## Source files to verify

- `SplunkAgent/Sources/SplunkAgent/Public API/API-1.0-EndpointConfiguration.swift`
- `SplunkAgent/Sources/SplunkAgent/Public API/Model/API-1.0-AgentConfigurationError.swift`
- `SplunkNetwork/Sources/SplunkNetwork/`
- `SplunkAgent/Sources/SplunkAgent/SplunkAgent.docc/Modules/Session-Replay.md`
- `SplunkAgent/Sources/SplunkAgent/SplunkAgent.docc/Modules/WebView-Instrumentation.md`
- `dsymUploader/README.md`

## Required output additions

- Safety gates checked.
- Secret findings count.
- Redacted values encountered, without reproducing values.
- Explicit approvals required.

## Rules

- Never introduce, copy, persist, print, or reproduce secrets.
- Never print raw SDK errors, `localizedDescription`, endpoint/configuration
  descriptions, request descriptors, headers, payloads, cookies, tokens, or
  token-like values.
- Do not copy public-doc examples that print `error` or
  `localizedDescription`; current `AgentConfigurationError` descriptions can
  include supplied endpoint or token values.
- Use placeholders in examples and the Host App's existing secret/configuration
  mechanism in code.
- Redact paths or identifiers when they include customer-private data.
- Do not enable high-risk features without explicit user approval.

High-risk features:

- Session Replay start or masking changes
- WebView Browser RUM bridge
- captured request or response headers
- endpoint update or custom endpoint URL
- dSYM upload and API-token handling
- CI workflow, Xcode build phase, or Xcode build setting changes

Reject obvious sensitive header capture:

```text
Authorization Cookie Set-Cookie X-SF-Token X-API-Key API-Key Session-Token
```

Before network changes, report that URL path/query can be captured and propose
`ignoreURLs` or span redaction for sensitive routes.
