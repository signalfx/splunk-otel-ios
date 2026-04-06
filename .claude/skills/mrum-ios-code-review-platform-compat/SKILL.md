---
name: mrum-ios-code-review-platform-compat
description: Apple platform compatibility review checklist. Covers availability guards, Mac Catalyst, XCFramework ABI, and multi-platform build concerns.
user-invocable: false
---

# Cross-Platform and Framework Compatibility

- iOS-only APIs used without `#available` or `#if os()` guards.
- Mac Catalyst: APIs unavailable or deprecated under Catalyst without `#if !targetEnvironment(macCatalyst)` guards (e.g., `UIScreen.main`, certain `UIDevice` properties, `UIStatusBarStyle` direct manipulation).
- Hardcoded screen size or scale factor assumptions.
- `UIDevice`/`WKInterfaceDevice` usage not guarded by platform.
- `Package.swift` platform entries not aligned with deployment minimums.
- XCFramework builds: `#if targetEnvironment(simulator)` logic that changes public API shape, conditional compilation that alters ABI between slices.
