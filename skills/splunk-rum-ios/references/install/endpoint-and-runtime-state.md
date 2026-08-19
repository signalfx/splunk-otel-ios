# Endpoint And Runtime State

## Guidance

Endpoint is optional in current public API. In Swift, use deferred endpoint
setup when the user has not supplied a safe token/config mechanism. In
Objective-C, identify that mechanism before installation because the current
public API has no safe deferred update path.

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

Objective-C has no public throwing runtime endpoint-update API. Assigning a
non-`nil` value to `agent.preferences.endpointConfiguration` can log a
validation error containing endpoint or token data. Do not generate that
update. Either provide the endpoint through the throwing `SPLKAgent` install
path and report only a generic failure, or report that deferred Objective-C
endpoint setup is not safely supported by the current public API. Assigning
`nil` to disable an endpoint is safe.

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
import, target membership, and API call compile correctly; deferred setup needs
no credentials for this check. After the build passes, deliver this handoff and
**stop — wait for the user to confirm before proceeding to telemetry or backend
verification steps.**

For Swift deferred setup, tell the user the agent is installed and will start,
but telemetry remains queued until an endpoint is configured. Ask which
existing Host App runtime configuration mechanism supplies both realm and
token, then wire its values into `EndpointConfiguration` and call the throwing
`updateEndpoint(_:)` path above. Surface only a generic failure signal.

For Objective-C, identify the existing configuration mechanism before
installation and pass its values through `SPLKEndpointConfiguration` to the
throwing install path. If the app requires a deferred endpoint, report the
public-API gap and stop rather than using the non-throwing preferences setter.
Do not invent a generic source, add literals, or ask for either value in
conversation.

After the user confirms local configuration, inspect only that the endpoint
wiring and applicable Swift update or Objective-C install call are present and
that no realm or token literal was committed. Do not read or validate either
value. Then continue to launch, signal, and backend verification as allowed.
