# Objective-C And Mixed App Verification

## Load when

Load when verifying Objective-C, storyboard Objective-C, or mixed Swift/ObjC
integrations.

## Do not load when

Do not load for pure Swift apps.

## Source files to verify

- ObjC lifecycle and UI files
- bridging headers
- package product linkage
- `SplunkAgent/Sources/SplunkAgentObjC/`
- relevant ObjC tests under `SplunkAgent/Tests/`

## Required output additions

- ObjC/mixed scenario covered.
- Product/linkage correctness.
- Swift-only leakage count.
- ObjC API citation coverage.

## Scenarios

Cover the scenario that matches the Host App:

- code-only Objective-C app
- storyboard Objective-C app
- mixed app with Swift-owned initialization
- mixed app with ObjC-owned initialization
- Swift app calling into ObjC helper code

Verify no Swift-only APIs were inserted into `.m` files. Verify ObjC snippets
compile against bridged API selectors.

