# Endpoint And Runtime State

## Load when

Load for deferred endpoint setup, endpoint update/disable, install status,
sampling, duplicate install, runtime state, or endpoint/config redaction.

## Do not load when

Do not load for a purely static plan that avoids endpoint and runtime-state
questions.

## Source files to verify

- `SplunkAgent/Sources/SplunkAgent/Public API/API-1.0-AgentConfiguration.swift`
- `SplunkAgent/Sources/SplunkAgent/Public API/API-1.0-EndpointConfiguration.swift`
- `SplunkAgent/Sources/SplunkAgent/Public API/SplunkRum+Endpoint.swift`
- `SplunkAgent/Sources/SplunkAgent/Public API/SplunkRum.swift`
- deferred endpoint tests under `SplunkAgent/Tests/`

## Required output additions

- Endpoint strategy: deferred, existing config, or approved explicit setup.
- Runtime state checks.
- Redaction note for endpoint/config/error values.
- Required approval before endpoint update/custom URL.

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
try agent.updateEndpoint(endpoint)
agent.disableEndpoint()
agent.preferences.endpointConfiguration = endpoint
agent.preferences.endpointConfiguration = nil
```

ObjC endpoint update uses `agent.preferences.endpointConfiguration`; assigning
`nil` disables the endpoint.

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

After placing a deferred-endpoint initialization, always deliver a handoff at
the end of `apply` output. Do not omit it. The user needs to know the app is
integrated but not yet sending data, and exactly what to do next.

**What the handoff must cover:**

1. State clearly that the SDK is integrated, the app builds, and the agent will
   start and generate signals locally — but nothing reaches Splunk Observability
   yet because no endpoint is configured.

2. Tell the user what they need to supply:
   - **Realm** — the short region identifier for their Splunk Observability
     organization (such as `us0`, `eu0`, `jp0`). Found in the organization URL
     or Settings in Splunk Observability Cloud.
   - **RUM access token** — a token with RUM ingest scope, created under
     Settings > Access Tokens in Splunk Observability Cloud.

3. Show how to add the endpoint without putting the token in source control.
   Use the app's existing safe config mechanism if one is visible. If none is
   apparent, show the environment-variable pattern as the safe default:

   ```swift
   // When ready to send telemetry — keep the token out of source control.
   let token = ProcessInfo.processInfo.environment["SPLUNK_RUM_TOKEN"] ?? ""
   let endpoint = EndpointConfiguration(realm: "<YOUR_REALM>", rumAccessToken: token)
   agent.preferences.endpointConfiguration = endpoint
   ```

   For Objective-C:

   ```objc
   // When ready to send telemetry — keep the token out of source control.
   NSString *token = NSProcessInfo.processInfo.environment[@"SPLUNK_RUM_TOKEN"] ?: @"";
   SPLKEndpointConfiguration *endpoint =
       [[SPLKEndpointConfiguration alloc] initWithRealm:@"<YOUR_REALM>"
                                         rumAccessToken:token];
   agent.preferences.endpointConfiguration = endpoint;
   ```

4. Note that `<YOUR_REALM>` and the token value are not in this output — the
   agent does not know them and must not guess them.

5. Tell the user what to expect: after supplying the endpoint and launching the
   app, a session for the app should appear in Splunk Observability Cloud RUM
   within a few minutes.

**Do not:**
- Hardcode or invent a realm value or token in any example, even a placeholder
  that looks like a real value.
- Suggest writing the token to a source file, committed plist, or any file that
  enters version control.
- Skip this handoff because the endpoint parameter is optional in the API — the
  user will not see data without it and needs the guidance.
