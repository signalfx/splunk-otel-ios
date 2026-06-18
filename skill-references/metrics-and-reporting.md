# Metrics And Reporting

## Load when

Load for every plan, review, apply, or verify report.

## Do not load when

Do not load only for a narrow code-snippet question where no report is needed.

## Source files to verify

- loaded topic references
- Host App files used as evidence
- build/test/launch command output when verification runs

## Required output additions

- Metrics table with numeric values where measurable.
- `not measured` plus reason when a value cannot be measured.
- Redacted evidence summary.

## Build metrics

Track during Skill Bundle development:

- top-level `SKILLS.md` nonblank line count, target `<= 180`
- reference manifest completeness
- routing precision and recall
- public API claim citation coverage
- unsafe top-level snippet count, target `0`
- public-release scrub score, target `1.00`
- validation matrix coverage

## Runtime metrics

Prefer continuous values:

- inspection coverage: inspected surfaces / expected surfaces
- evidence coverage: plan claims with local evidence / total plan claims
- app-shape inspection coverage
- secret findings introduced, target `0`
- redaction coverage
- unsupported-platform refusal rate
- migration completeness
- diff focus and diff size
- build error burndown
- launch success ratio
- no-credential verification coverage
- local signal exercise coverage
- backend signal coverage and ingestion latency
- dSYM readiness

## Report shape

For plans: evidence, recommended path, references loaded, proposed changes,
required values/approvals, verification plan, metrics, risks.

For dSYM: generation, upload location, token source, dry-run result,
release-only guard, failure policy, remaining blocker.

For troubleshooting: symptom branch, inspected evidence, likely cause, safe next
action, references loaded, redacted values encountered.

