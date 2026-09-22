# SplunkCrashReporter maintenance

Copyright 2026 Splunk Inc.

SplunkCrashReporter is the SDK-owned, symbol-prefixed vendored copy of
Microsoft PLCrashReporter used by the iOS agent. It is kept in this repository
so the agent can ship crash reporting without introducing a second upstream
PLCrashReporter dependency into client applications.

## Upstream baseline

- Upstream project: [Microsoft PLCrashReporter](https://github.com/microsoft/plcrashreporter)
- Baseline release: `1.12.2`
- Baseline commit: [`0254f94`](https://github.com/microsoft/plcrashreporter/commit/0254f94)
- Maintainers: `@signalfx/mrum-ios-maintainers` (see `.github/CODEOWNERS`)

The vendored source must continue to be attributable to this exact upstream
baseline or to a later explicitly recorded upstream commit. The upstream
license and notices are retained in this directory.

## Local adaptations

The following changes are intentionally maintained on top of the upstream
baseline:

1. All exported Objective-C and C names are prefixed with `SPLK` so the SDK
   can coexist with an application or another dependency that contains
   PLCrashReporter. Public C typedefs, enum constants, callbacks, and globals
   are included in the prefix map. The umbrella header removes the temporary
   namespace macros after importing the public declarations so they cannot
   rewrite identifiers in a separately imported upstream PLCrashReporter.
2. `PLCrashLogWriter.m` uses `strnlen` when recording `process_path`, preserving
   the available length rather than relying on a terminating NUL byte.
3. `PLCrashReporter.m` uses a process-wide mutex for the one-reporter
   interlock.
4. The configured `maxReportBytes` value is copied into the signal-handler
   context, so fatal reports use the same 1 MiB default/configuration as live
   reports.
5. The SPM and xcframework packaging integrate the prefixed implementation as
   the `SplunkCrashReporter` target.

The source-history references for the current local patches are:

- `91b0c294` — process-path length handling while updating the vendored source.
- `4f92db83` — crash-reporter interlock.
- `ad1655b8` and `0a40d09a` — Objective-C and public C symbol prefixing.
- `0a804bac` — resynchronization with upstream PLCrashReporter 1.12.2.

## Update and security process

When updating PLCrashReporter:

1. Review the upstream release notes, source diff, open security advisories,
   and license changes. Start from the exact upstream tag/commit.
2. Diff the vendored `Source/` and public headers against that baseline. Reapply
   and re-audit every local adaptation listed above; do not copy an upstream
   source file over the namespace and crash-size changes without reviewing the
   resulting diff.
3. Update this file with the new upstream tag/commit, patch inventory, and
   validation record. Keep the upstream license and notices synchronized.
4. Keep `Package.swift` and `tools/xcframework/Project.swift` synchronized and
   run `tools/xcframework/scripts/check-manifest-sync.sh` if either manifest
   changes.
5. Obtain review from the MRUM iOS maintainers. For suspected vulnerabilities,
   follow the repository [security reporting process](../SECURITY.md) rather
   than opening a public GitHub issue.

The security review must specifically consider signal-handler async-safety,
crash-file contents and privacy, parser/decoder changes, memory bounds, and
any new third-party code.

## Validation record

Every update must include both automated coverage and a device/simulator
crash-flow check. The automated checks for this implementation are:

```text
xcodebuild -scheme SplunkAgent -destination "generic/platform=iOS Simulator" build
xcodebuild -scheme SplunkAgent -destination "OS=18.6,name=iPhone 16" test -only-testing:SplunkCrashReportsTests
xcodebuild -project Applications/AgentTestApp/AgentTestApp.xcodeproj \
  -scheme AgentTestApp -destination "OS=18.6,name=iPhone 16" \
  -derivedDataPath /private/tmp/splunk-agent-e2e-derived build
```

The crash-flow check installs the built AgentTestApp, opens its Crashes screen
and triggers the fatal-error action (or uses an equivalent controlled fatal
signal), relaunches the app, and verifies that the crash report is present and
can be consumed by the agent. The check must also verify that the next launch
does not repeatedly report the same file.

Recorded on 2026-09-11 for the current 1.12.2 resynchronization:

- `AgentTestApp` build: passed.
- `SplunkCrashReportsTests`: passed, 128 tests, 0 failures (run on the iPhone
  16 / iOS 18.6 simulator destination).
- Crash/relaunch E2E: passed on the iPhone 16 / iOS 18.6 simulator. The clean
  install was launched, a controlled `SIGSEGV` was sent to the app process,
  `live_report.plcrash` was observed in the app's
  `Documents/SplunkCrashReports/...` directory, and the app was relaunched.
  After the relaunch, the pending-report directory was empty and trace files
  were present in the disk-backed OTLP exporter queue, confirming capture,
  consumption, purge, and durable persistence.
