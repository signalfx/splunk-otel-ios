---
name: mrum-ios-code-review-formatting
description: Swift code formatting review checklist. Covers swift-format, swiftformat, and swiftlint tool integration and config file deference.
user-invocable: false
---

# Code Formatting

## Tools
The project may use up to three formatting/linting tools with custom config files:
- `swift-format` (Apple's official formatter)
- `swiftformat` (Nicklockwood's SwiftFormat)
- `swiftlint` (Realm's SwiftLint)

## Review Approach
- Look for project config files (`.swift-format`, `.swiftformat`, `.swiftlint.yml`) to understand custom rules in effect.
- Do not flag style issues that contradict the project's configured rules.
- Flag code that would likely trigger linter/formatter violations, but defer to tool configs as source of truth for style.
- Do not suggest formatting changes that conflict with the configured tools — the tools handle formatting. Focus review energy on logic, correctness, and design.
