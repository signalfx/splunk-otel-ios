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

**2. Supply the token via the app's existing secret/configuration mechanism.**
The realm is not a secret and may live in source. The token is a secret and
must not be pasted into this conversation, committed to source, written into a
shared Xcode scheme, plist, example, log, or screenshot.

Ask the user which secret or configuration mechanism their app already uses —
do not invent a project-specific store without inspecting the project and
getting user approval. Give this tiered guidance:

- **App already has a mechanism** (e.g. a secrets manager, an encrypted config
  file, a gitignored local config): use that. Inspect and describe the path.
- **Local development, no existing mechanism**: use an explicitly untracked
  local source. Two simple options: a gitignored `.xcconfig` file with a
  `SPLUNK_RUM_TOKEN = <value>` build setting, or a gitignored `.env` file
  sourced by a launch script that sets the environment variable before running
  the app.
- **CI and release builds**: use the CI system's encrypted secrets or the
  approved release-time secret injection process. Do not invent a CI workflow
  without knowing which CI system the project uses.

Note: if the user wants to supply the token via `ProcessInfo.processInfo
.environment["SPLUNK_RUM_TOKEN"]` (what the written code already reads), the
value must reach the running process through one of the above mechanisms —
not through a shared Xcode scheme Run-action environment variable, which
can be committed if the scheme is shared, and which does not apply to
archive, TestFlight, or App Store builds.

Ask the user to make both edits (realm in source, token via their chosen
mechanism) and report back when done. Do not proceed further until they confirm.

### After the user reports back

Read the instrumentation file (the same file named during `apply`) to check the
realm placeholder has been replaced. Do not read, request, or ask about the
token value — it lives in the user's chosen secret mechanism and must not be
seen or repeated by this agent.

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
