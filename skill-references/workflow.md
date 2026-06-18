# Workflow

## Load when

Load for every task using this Skill Bundle.

## Do not load when

Do not load only if the user explicitly asks for a non-Splunk, non-iOS task.

## Source files to verify

- `SKILLS.md`
- `README.md`
- `CHANGELOG.md`
- `Package.swift`
- `SplunkAgent/Sources/SplunkAgent/SplunkAgent.docc/`
- `SplunkAgent/Sources/SplunkAgent/Public API/`
- `SplunkAgent/Sources/SplunkAgentObjC/`

## Required output additions

- Mode used: `plan`, `review`, `apply`, `verify`, or `sample`.
- References loaded and why.
- Evidence table for claims about the Host App.
- Approvals needed before edits or high-risk behavior.

## Procedure

1. Identify the requested mode. Default to `plan` / `review`.
2. Inspect before deciding. Do not assume app lifecycle, language, platform, or
   dependency manager.
3. Check Host App version-control state before `apply`. If dirty, report branch
   and changed files and require explicit confirmation.
4. Load only the topic references needed by Host App evidence.
5. Produce a plan before edits. Update the plan if new evidence changes the
   safest integration point.
6. Keep edits scoped to Splunk RUM dependency/linkage, initialization, explicit
   instrumentation, and approved release/build-phase work.
7. Verify in layers: static review, dependency resolution, build, launch, safe
   signal exercise, backend only when user-provided public access is available.

## Current-source rule

Do not rely on memory for SDK version, module defaults, or API syntax. Check the
current local source and public release/docs when the answer depends on current
state. If docs disagree with public API source, prefer source and report the
mismatch.

