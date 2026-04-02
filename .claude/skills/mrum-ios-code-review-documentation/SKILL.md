---
name: mrum-ios-code-review-documentation
description: Swift/ObjC documentation review checklist. Covers DocC conventions, comment styles, and public API documentation requirements.
user-invocable: false
---

# Documentation (DocC)

## Comment Styles
- `///` (triple-slash) for documentation comments on declarations: types, properties, methods, enum cases, protocols. These feed DocC and Xcode Quick Help.
- `//` (double-slash) for inline implementation comments explaining *why*, not *what*.

## Public API Documentation
- All `public` and `open` declarations must have `///` documentation. Flag undocumented public API.
- Use DocC markup: `- Parameters:`, `- Returns:`, `- Throws:`, `- Note:`, `- Important:`, `- Warning:`, code references in double backticks `` ``ClassName`` ``.

## What NOT to Flag
- Missing docs on `internal`, `fileprivate`, or `private` declarations — optional.
- Do not request comment bloat. No restating the obvious (e.g., `/// The name` on a property called `name`).

## Inline Comments
- For non-obvious or interesting implementation choices, an inline `//` comment explaining the *why* is preferred.
- Assume the reader is an expert iOS developer — explain rationale and trade-offs, not basic mechanics.
