# Network

## Guidance

Keep default network instrumentation. Add URL exclusions only for inspected
sensitive routes or the user's explicit request, and do not capture headers by
default.

Network instrumentation can capture URL-derived attributes, including path,
query, and the full URL. Before changing network behavior, report sensitive
route risk. Use `ignoreURLs` when dropping the matching span is acceptable.
The Network module has no URL-rewrite setting. When the span must be retained,
use the public `AgentConfiguration.spanInterceptor` only with explicit approval,
scope the transform to matching network spans, and inspect current source for
every URL-bearing attribute that must be removed or replaced.

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
narrow allowlist. Reject these sensitive names:

```text
Authorization Cookie Set-Cookie X-SF-Token X-API-Key API-Key Session-Token
```

`capturedRequestHeaders` and `capturedResponseHeaders` default to `nil`; only
add non-sensitive names such as `Content-Type` or a request correlation header
after approval.

Trace-header injection can affect downstream systems. Treat changes as
configuration work and call out compatibility risks.
