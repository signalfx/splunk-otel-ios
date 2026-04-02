---
name: mrum-ios-code-review-memory-safety
description: Swift/ObjC memory safety review checklist. Covers retain cycles, force unwraps, data races, unsafe pointers, and ObjC nullability.
user-invocable: false
---

# Memory Safety and Correctness

## Retain Cycles
- Closures capturing `self` without `[weak self]` or `[unowned self]` where the closure outlives the caller: escaping closures stored on long-lived objects, completion handlers, NotificationCenter observers, Combine sinks, delegate callbacks.
- Do NOT flag: non-escaping closures, short-lived animation blocks, `Task { }` blocks on actors.

## Force Unwraps
- `!` on optionals that could realistically be nil at runtime.
- Acceptable: `IBOutlet`s, known-safe patterns like `URL(string: "https://...")!` with literal strings, immediately-after-guard-let.

## Unowned References
- `unowned` where the referenced object could be deallocated. Prefer `weak` unless the lifetime relationship is guaranteed.

## Unsafe Pointers
- `UnsafePointer`, `UnsafeMutablePointer`, `UnsafeRawPointer` usage without clear justification.

## Data Races
- Mutable shared state accessed from multiple threads/queues without synchronization (locks, actors, serial queues, `@Sendable` compliance).

## Objective-C Nullability
- Missing `nullable`/`nonnull` annotations on public API.
- Missing `NS_ASSUME_NONNULL_BEGIN/END`.
