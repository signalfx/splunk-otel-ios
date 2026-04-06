---
name: mrum-ios-code-review-ui-frameworks
description: UIKit and SwiftUI review checklist. Covers lifecycle, layout, state management, and cross-platform UI patterns.
user-invocable: false
---

# UIKit / SwiftUI

## UIKit
- Missing `prepareForReuse()` in cells.
- Incorrect lifecycle method usage (`viewDidLoad` vs `viewWillAppear`).
- Autolayout constraint conflicts or ambiguity.
- Missing `setNeedsLayout`/`layoutIfNeeded` calls.

## SwiftUI
- Views with too much logic in `body` — extract subviews.
- `@State` for non-value types.
- `@ObservedObject` where `@StateObject` is needed (ownership).
- Unnecessary `AnyView` type erasure.
- Missing `.task` cancellation awareness.
- Environment misuse.

## Cross-Platform UI
- `#if os(iOS)` / `#available` checks for platform-specific API.
- iOS-only API usage without guards when targeting multiple platforms.
