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

