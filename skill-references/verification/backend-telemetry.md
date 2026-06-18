# Backend Telemetry

## Load when

Load when the user asks to confirm data in Splunk Observability Cloud and has
provided safe public Splunk access or wants a credentialed verification plan.

## Do not load when

Do not load when no backend access is available; use local verification instead.

## Source files to verify

- Host App endpoint/config mechanism
- public Splunk RUM docs for data lookup
- signal generation steps used during verification

## Required output additions

- Credential/access status without reproducing secrets.
- Observed signal types / expected signal types.
- Ingestion latency.
- Redacted evidence summary.

## Guidance

Do not use internal Splunk systems, private realms, private query scripts, or
private backend workflows in public Runtime Skill output.

If access is available, confirm:

- session or app launch visibility
- selected screen/navigation signal
- selected network signal
- selected custom event/error signal
- dSYM/crash symbolication only when a safe release test is in scope

Allow ingestion latency before declaring telemetry missing. Report timestamps,
signal types, and redacted identifiers only.
