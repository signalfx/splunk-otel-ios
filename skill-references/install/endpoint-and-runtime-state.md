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

After writing the initialization code, always deliver this handoff at the end
of `apply` output and then **stop and wait for the user to respond** before
proceeding to any build, test, or telemetry verification steps. Do not omit
the handoff. Do not proceed past it without the user's confirmation.

### What to tell the user

The initialization code has been written to the file, including the endpoint
block with `<YOUR_REALM>` as a placeholder. The app will build and run, but no
telemetry reaches Splunk Observability Cloud until the user fills in two values:

- **Realm** — replace `<YOUR_REALM>` in the source file with the short region
  identifier for their organization (e.g. `us0`, `eu0`, `jp0`). Found in the
  organization URL or under Settings in Splunk Observability Cloud.
- **RUM access token** — set as the `SPLUNK_RUM_TOKEN` environment variable in
  their Xcode scheme. Create the token under Settings > Access Tokens in Splunk
  Observability Cloud (RUM ingest scope required).

### How the user should make these edits

The token must not pass through this conversation. Do not ask the user to type
or paste their token here. If the user offers to share the token, politely
decline and explain that keeping it out of the conversation is the safest
approach.

Direct the user to make both edits themselves:

**1. Replace the realm placeholder in source** — name the exact file and line
written during `apply`. The user opens it in any local editor (Xcode, VS Code,
Emacs, Vim, etc.) and replaces `"<YOUR_REALM>"` with their actual realm string.
This edit is safe to commit; the realm is not a secret.

**2. Set the token in the Xcode scheme** — the code already reads the token
from `ProcessInfo.processInfo.environment["SPLUNK_RUM_TOKEN"]` at runtime.
To supply the value without putting it in source control:
- Open the scheme editor: Product > Scheme > Edit Scheme (or long-press Run)
- Select the Run action, then the Arguments tab
- Under "Environment Variables", add `SPLUNK_RUM_TOKEN` with their token value

Briefly explain why this is the right pattern: the realm can live in source
because it is not a secret; the token is kept out of source control by living
only in the scheme's local environment variables, which Xcode does not commit
to the repository by default.

Ask the user to make both edits and report back when done. Do not proceed
further until they confirm.

### After the user reports back

Read the instrumentation file (the same file named during `apply`) to check the
realm placeholder has been replaced. Do not read the Xcode scheme file; the
token lives there and must not be seen or repeated by this agent.

Check the source file for two things only:
- The realm field does not look like a placeholder. A placeholder looks like
  `<YOUR_REALM>`, `YOUR_REALM`, `realm`, `<realm>`, an empty string, or a
  short generic word. A real realm looks like `us0`, `eu0`, `jp0`, `us1`, etc.
- The `EndpointConfiguration` call is present and structurally complete.

Do not read, repeat, log, or store the token value. The check is structural
only: does it look like the user filled in a real realm, and is the
`EndpointConfiguration` call in place?

If both look good, say something like "It looks like the realm and token are
already set up — ready to move on to building and running the app." Then
continue with build and verification guidance.

If the realm still looks like a placeholder or the `EndpointConfiguration`
call is missing, point the user back to the specific line and ask them to
complete the edit.

**Do not:**
- Ask the user to paste, type, or share their token in conversation.
- Offer to make the realm or token edit yourself — direct the user to their editor.
- Hardcode or guess a realm value in any example.
- Echo back or summarize the token value after reading the file.
- Suggest writing the token to any source file, plist, or other file that
  enters version control.
