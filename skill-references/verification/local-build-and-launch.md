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

