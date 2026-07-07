# Endpoint And Runtime State

Load for deferred endpoint setup, endpoint update/disable, install status,
sampling, duplicate install, runtime state, or endpoint/config redaction. Also
load for every fresh install apply (see post-apply handoff below).

## Guidance

Endpoint is optional in current public API. Use deferred endpoint setup when the
user has not supplied a safe token/config mechanism.

Runtime state is available through `agent.state.status`. Source-backed status
cases are `.running`, `.notRunning(.notInstalled)`,
`.notRunning(.unsupportedPlatform)`, and `.notRunning(.sampledOut)`. On
compile-only runtime scopes, install can return the shared non-operational
instance with `.notRunning(.unsupportedPlatform)`.

Swift endpoint update APIs:

```swift
// Preferred: throwing path lets the caller handle failures without logging secrets.
try agent.updateEndpoint(endpoint)

// To disable:
agent.disableEndpoint()
agent.preferences.endpointConfiguration = nil
```

Avoid `agent.preferences.endpointConfiguration = endpoint` for Swift updates:
the setter catches failures internally and logs the raw error, which may include
the endpoint URL or token — contradicting the redaction rule below.

ObjC endpoint update uses `agent.preferences.endpointConfiguration`; assigning
`nil` disables the endpoint. The ObjC path does not have a separate throwing
variant; treat it as informational only and do not use it to validate
arbitrary user-entered endpoint values.

Do not print:

- `EndpointConfiguration.description`
- `AgentConfigurationError.description`
- raw `error` or `localizedDescription`
- endpoint URLs with customer-specific data
- token-like values

Duplicate install is not a thrown error in current source; the SDK returns the
existing shared instance. For duplicate-install symptoms, inspect call sites and
explain behavior instead of adding another install path.

Endpoint update and disable APIs are public, but they change telemetry routing.
Require explicit approval and use placeholders in any example.

## Post-apply handoff

After writing initialization code, deliver this handoff and **stop — wait for
the user to confirm before proceeding to build or verification steps.**

Tell the user: the agent is installed and will start, but telemetry is queued
locally and not sent until an endpoint is configured. To start sending data,
they need to add the following after the `SplunkRum.install` call — in their
local editor, not through this conversation:

```swift
// Add your realm (not a secret; safe to commit). Supply the token via your
// app's existing secret/config mechanism — never paste it here or commit it.
let token = ProcessInfo.processInfo.environment["SPLUNK_RUM_TOKEN"] ?? ""
let endpoint = EndpointConfiguration(realm: "<YOUR_REALM>", rumAccessToken: token)
splunkRum?.preferences.endpointConfiguration = endpoint
```

For ObjC, use `agent.preferences.endpointConfiguration` with
`SPLKEndpointConfiguration`.

The token is a secret. Do not ask the user to paste it here; if offered,
decline. Ask which secret/config mechanism their app already uses (secrets
manager, gitignored local config, CI encrypted secrets) and use that. For
local dev with no existing mechanism, a gitignored `.xcconfig` or `.env` is a
safe starting point. Shared Xcode scheme Run-action env vars can be committed
and do not apply to archive/TestFlight/App Store builds — avoid them.

After the user reports back: read the source file to check `<YOUR_REALM>` has
been replaced with something that looks like a real realm (e.g. `us0`, `eu0`).
Do not read, echo, or store the token. If the realm looks real and the endpoint
call is present, say something like "It looks like the realm and token are
already set up" and continue. Otherwise point the user back to the specific line.
