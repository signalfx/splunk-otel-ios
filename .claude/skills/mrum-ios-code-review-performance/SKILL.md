---
name: mrum-ios-code-review-performance
description: Swift/ObjC performance review checklist. Covers main thread work, lazy properties, type erasure overhead, and data layer performance.
user-invocable: false
---

# Performance

- Large allocations or work on the main thread.
- Missing `lazy` for expensive properties only sometimes accessed.
- Unnecessary `AnyPublisher` / `any Protocol` type erasure (boxing overhead).
- Objective-C: property attributes (`copy` vs `strong` for value types like `NSString`, `NSArray`).
- Excessive `@objc dynamic` without need for KVO.
- Image/asset loading without caching or on main thread.
- Core Data / SwiftData: fetches on main context, missing batch operations for bulk updates.
