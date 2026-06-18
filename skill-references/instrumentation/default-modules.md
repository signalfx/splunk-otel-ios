# Default Modules

## Load when

Load when explaining SDK defaults, app startup/state, crash runtime behavior,
slow/frozen frames, or interaction tracking.

## Do not load when

Do not load for a narrow task involving only high-risk feature setup.

## Source files to verify

- `SplunkAgent/Sources/SplunkAgent/SplunkAgent.docc/Modules-Overview.md`
- `SplunkAgent/Sources/SplunkAgent/SplunkAgent.docc/Modules/App-Startup-Tracking.md`
- `SplunkAgent/Sources/SplunkAgent/SplunkAgent.docc/Modules/Crash-Reporting.md`
- `SplunkAgent/Sources/SplunkAgent/SplunkAgent.docc/Modules/Slow-and-Frozen-Frame-Detection.md`
- `SplunkAgent/Sources/SplunkAgent/SplunkAgent.docc/Modules/UI-Interaction-Tracking.md`
- public API module configuration files

## Required output additions

- Which default modules are relevant.
- Any explicit module configuration changes proposed.
- Approval needed for config changes that alter behavior.

## Guidance

Treat app startup, app state, crash runtime capture, slow/frozen frame
detection, and interaction tracking as baseline SDK capabilities, subject to
current source and module configuration.

Crash runtime capture is separate from dSYM upload. Use
`release/crash-and-dsym.md` for symbolication upload setup.

Do not promise exact backend visibility without verification. Report selected
signal types and how they will be exercised.

