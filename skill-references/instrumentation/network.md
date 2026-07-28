# Network

Load for `URLSession`, network monitoring, ignored URLs, trace headers,
captured headers, network privacy review, or no-network-telemetry symptoms.

## Depth guidance

- `baseline`: keep default network instrumentation. Add URL exclusions only
  for inspected sensitive routes or the user's explicit request. Do not capture
  headers.
- `targeted`: add narrow URL exclusions, trace-header compatibility notes, or
  approved non-sensitive header allowlists for specific inspected services.
- `comprehensive`: inventory network wrappers, session creation, sensitive
  routes, trace propagation, and approved header capture needs. Keep suppression
  patterns narrow.

## Guidance

Network instrumentation can capture URL path/query and full URL attributes.
Before changing network behavior, report sensitive route risk and consider
`ignoreURLs`. There is no supported hook to sanitize a captured URL while
keeping the span; if a URL must be kept but a sensitive path segment must be
hidden, report it as a gap rather than inventing an unsupported solution.

Swift module configuration types live in `SplunkNetwork`; import it when using
`NetworkInstrumentationConfiguration` or `IgnoreURLs`:

```swift
import SplunkAgent
import SplunkNetwork

let ignored = try IgnoreURLs(patterns: [
    #"^https://api\.example\.com/private/"#
])

let networkConfig = NetworkInstrumentationConfiguration(
    ignoreURLs: ignored
)
```

`IgnoreURLs` uses regular expressions against URL strings. Prefer narrow,
anchored patterns for sensitive routes instead of broad host-wide suppression.

Header capture is opt-in and high risk. Require explicit user approval and a
narrow allowlist. Reject the sensitive headers listed in `workflow.md`.
`capturedRequestHeaders` and `capturedResponseHeaders` default to `nil`; only
add non-sensitive names such as `Content-Type` or a request correlation header
after approval.

Trace-header injection can affect downstream systems. Treat changes as
configuration work and call out compatibility risks.
