# Network

## Load when

Load for `URLSession`, network monitoring, ignored URLs, trace headers,
captured headers, network privacy review, or no-network-telemetry symptoms.

## Do not load when

Do not load when no network instrumentation is involved.

## Source files to verify

- `SplunkAgent/Sources/SplunkAgent/SplunkAgent.docc/Modules/Network-Monitoring.md`
- `SplunkNetwork/Sources/SplunkNetwork/`
- `SplunkAgent/Sources/SplunkAgentObjC/Modules/Network/`
- Host App network wrappers and `URLSession` call sites

## Required output additions

- Network surfaces inspected.
- URL/query privacy assessment.
- Header capture approval state and allowlist if applicable.
- Ignored URL patterns proposed.

## Guidance

Network instrumentation can capture URL path/query and full URL attributes.
Before changing network behavior, report sensitive route risk and consider
`ignoreURLs` or span redaction.

Header capture is opt-in and high risk. Require explicit user approval and a
narrow allowlist. Reject sensitive headers listed in
`privacy-and-security.md`.

For "exclude some URLs from monitoring" requests, inspect the Host App routes
and propose the narrowest stable regex or matching strategy. Do not suppress
more traffic than necessary.

Trace-header injection can affect downstream systems. Treat changes as
configuration work and call out compatibility risks.

