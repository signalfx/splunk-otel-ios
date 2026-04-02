---
name: mrum-ios-code-review-concurrency
description: Swift/ObjC concurrency review checklist. Covers Swift Concurrency, GCD, Combine, actor isolation, and task cancellation.
user-invocable: false
---

# Concurrency

## Main Thread Violations
- UI updates not on `@MainActor` or `DispatchQueue.main`.

## Sendable Conformance
- Non-sendable types crossing isolation boundaries.

## Actor Isolation
- Accessing actor-isolated state from outside without `await`.

## GCD Pitfalls
- Nested `sync` calls risking deadlocks.
- `DispatchQueue.main.sync` from main thread.

## Combine
- Missing `store(in:)` for cancellables.
- Publishers not cancelled on deinit.
- `receive(on:)` placement.

## Task Cancellation
- Long-running tasks not checking `Task.isCancelled` or using `Task.checkCancellation()`.
