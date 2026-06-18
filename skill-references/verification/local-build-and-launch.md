# Local Build And Launch Verification

## Load when

Load for local build, simulator launch, dependency verification, or `verify`
mode without backend access.

## Do not load when

Do not load for static review only unless build/launch is requested.

## Source files to verify

- Host App project/workspace and schemes
- Host App CI/build docs
- package resolution files
- simulator destination availability

## Required output additions

- Build command and result.
- Launch method and result.
- Platform note only when non-iOS targets affect interpretation of results.
- Build errors remaining.
- Launch attempts and successes.

## Guidance

Use the Host App's established build path when available. Prefer standard
simulator destinations already used by the project or CI.

Verification layers:

1. static review
2. dependency resolution
3. build
4. launch
5. safe local signal exercise
6. backend only with user-provided public access

Stop and report hard blockers, but continue lower-cost static checks when
useful.

Do not require Splunk credentials for build and launch verification when using
deferred endpoint setup.

A build or launch on a compile-only/non-operational platform is valid build/run
evidence, but not telemetry verification. Do not ask the user to add app-side
platform fences. If the distinction matters, explain that RUM signal
verification requires an iOS/iPadOS runtime.
