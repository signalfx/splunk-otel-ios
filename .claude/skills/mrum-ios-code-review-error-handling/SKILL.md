---
name: mrum-ios-code-review-error-handling
description: Swift/ObjC error handling review checklist. Covers catch blocks, silent errors, Result types, and network error patterns.
user-invocable: false
---

# Error Handling

- Empty `catch` blocks or `catch` with only a `print`.
- `try?` silently swallowing errors that should be surfaced to the user.
- Missing `Result` or typed throws where callers need error details.
- Network calls without timeout, retry, or cancellation handling.
- Objective-C: missing `NSError **` out-parameters in methods that can fail.
