# Build And Link Errors

## Load when

Load when package resolution, product linkage, imports, minimum platform,
binary target resolution, or clean-build failures appear.

## Do not load when

Do not load for a clean plan with no dependency or build concerns.

## Source files to verify

- Host App `.xcodeproj/project.pbxproj`, `Package.swift`, `Package.resolved`
- `Podfile` or other dependency manifests if present
- `Package.swift`
- `README.md`
- `SplunkAgent/Sources/SplunkAgentObjC/`

## Required output additions

- Build/link symptom.
- Product/import decision.
- Stale package findings.
- Safe next command or edit.

## Triage

Check:

- package URL typo or stale fork
- product mismatch: `SplunkAgent` for Swift, `SplunkAgentObjC` for ObjC
- stale `SplunkOtel` product/import
- wrong target linkage or package added only to a test target
- unsupported platform destination
- stale `Package.resolved`
- Xcode package cache state
- binary target resolution failure
- ObjC `@import SplunkAgentObjC;` missing product linkage

Do not delete package resolution files unless the Host App workflow allows it.
Prefer reporting the stale file and asking for approval before cleanup.

If fixing, preserve existing dependency style and version pinning policy.

