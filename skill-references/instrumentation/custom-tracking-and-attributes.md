# Custom Tracking And Attributes

## Load when

Load for custom events, handled errors, workflows, user/session/global
attributes, or business telemetry recommendations.

## Do not load when

Do not load for automatic-only setup unless custom telemetry is requested or
detected.

## Source files to verify

- `SplunkAgent/Sources/SplunkAgent/SplunkAgent.docc/Modules/Custom-Event-and-Workflow-Reporting.md`
- `SplunkAgent/Sources/SplunkAgent/Public API/Modules/Custom Tracking/`
- `SplunkAgent/Sources/SplunkAgent/Public API/API-1.0-AgentConfiguration.swift`
- `SplunkAgent/Sources/SplunkAgentObjC/Modules/Custom Tracking/`

## Required output additions

- Custom telemetry opportunities and evidence.
- Attribute privacy review.
- Workflow-span start/end ownership if workflows are recommended.

## Guidance

Recommend custom events for business milestones, handled errors for expected
error paths, and workflows for timed operations with clear start/end points.

Keep attributes low-cardinality and non-sensitive. Do not add names, emails,
addresses, account numbers, auth identifiers, or other PII unless the user has
explicit product/privacy approval and a safe policy.

For ObjC, verify bridged API availability before suggesting selectors. Do not
use Swift-only workflow APIs in `.m` files unless the bridge supports them.

