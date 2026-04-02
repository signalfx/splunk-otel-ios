---
name: mrum-ios-code-review-testability
description: Swift/ObjC testability review checklist. Covers dependency injection, singletons, side effects, and method complexity.
user-invocable: false
---

# Testability

- Concrete dependencies that should be injected via protocols.
- Singletons without a way to substitute in tests.
- Side effects in initializers.
- Methods doing too many things (hard to unit test).
