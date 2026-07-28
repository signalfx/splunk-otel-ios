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

After writing initialization code, run a static build check to confirm the
import, target membership, and API call compile correctly — deferred endpoint
setup means no credentials are needed to build or launch. Only after the build
passes, deliver this handoff and **stop — wait for the user to confirm before
proceeding to telemetry or backend verification steps.**

Tell the user the agent is installed and will start, but telemetry remains
queued until an endpoint is configured. Ask which existing Host App runtime
configuration mechanism supplies both realm and token. Do not invent a generic
source, add literals, or ask for either value in conversation.

Once the mechanism is identified, wire its values into
`EndpointConfiguration`. For Swift, call the throwing `updateEndpoint(_:)` path
above and surface only a generic failure signal. For Objective-C, use
`agent.preferences.endpointConfiguration` with `SPLKEndpointConfiguration` and
only values supplied by the inspected runtime configuration mechanism; do not
use the setter as a validation probe.

After the user confirms local configuration, inspect only that the
`EndpointConfiguration` wiring and endpoint update call are present and that no
realm or token literal was committed. Do not read or validate either value.
Then continue to launch, signal, and backend verification as allowed.
