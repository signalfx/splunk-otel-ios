# Local Signal Generation

## Load when

Load when verifying safe signal exercise without backend credentials or when
checking no-credential behavior.

## Do not load when

Do not load for build-only verification.

## Source files to verify

- Host App screens and navigation
- Host App network layer
- custom event/error call sites
- `SplunkAgent/Sources/SplunkAgent/Agent/Events/`
- background exporter storage code when pending-artifact checks are considered

## Required output additions

- Safe signal types exercised.
- Pending-artifact delta if safely measurable.
- Evidence redaction note.

## Guidance

Safe no-credential exercises:

- app start and launch
- one screen/navigation event
- one benign `URLSession` request
- one custom event or handled error

Do not print telemetry payloads, request descriptors, headers, endpoint values,
or stored payload contents. If pending-artifact counts are inspected, report
counts only by signal type when safely discoverable.

Do not start Session Replay or bridge WebViews as part of default signal
exercise.

