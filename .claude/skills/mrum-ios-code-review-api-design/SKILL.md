---
name: mrum-ios-code-review-api-design
description: Swift/ObjC API design review checklist. Covers naming, access control, ObjC interop, protocol design, and value vs reference semantics.
user-invocable: false
---

# API Design and Swift/ObjC Conventions

## Naming
- Follows Swift API Design Guidelines: clarity at point of use, fluent usage, term of art.

## Objective-C Interop
- `@objc` exposure where needed.
- `NS_SWIFT_NAME` for better Swift names.
- Proper bridging of nullability and generics.

## Access Control
- Overly broad access (`public`/`open`) where `internal` or `private` suffices.

## Protocol Design
- Large conformances that should be split into extensions for readability.

## Value vs Reference Semantics
- Structs with reference-type properties.
- Classes that should be structs.
