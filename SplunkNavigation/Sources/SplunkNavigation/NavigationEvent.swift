//
/*
Copyright 2026 Splunk Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

import Foundation

/// The result of processing an automated navigation event.
///
/// Returned by ``NavigationEventProcessor/onViewController(typeName:controllerIdentity:)``
/// to describe how a detected screen transition should be recorded. The ``name`` becomes the
/// `navigation.name` span attribute, and any ``attributes`` are added to the navigation span.
public final class NavigationEvent {

    // MARK: - Public

    /// The screen name to use for this navigation event.
    ///
    /// This value is set as the `navigation.name` and `screen.name` span attributes.
    public let name: String

    /// An opaque string that identifies the tracked view controller instance.
    ///
    /// The value is:
    /// - **Opaque** — consumers must not parse it or derive the underlying controller.
    /// - **Unique** among simultaneously live instances within a single process.
    /// - **Stable** for the lifetime of the controller instance.
    /// - **Reusable** — the same value may appear after the instance is deallocated.
    /// - **Not persistent** across app launches.
    ///
    /// Use `==` (or `-isEqualToString:` from Objective-C) for comparison.
    public let controllerIdentity: String

    /// Custom attributes to include in the navigation span.
    ///
    /// Use this to enrich navigation spans with application-specific metadata
    /// (e.g., content identifiers, feature flags, or section names).
    public let attributes: [String: Any]?


    // MARK: - Initialization

    /// Creates a navigation event.
    ///
    /// - Parameters:
    ///   - name: The screen name for this navigation event.
    ///   - controllerIdentity: String representation of the view controller identity.
    ///   - attributes: Optional custom attributes to include in the navigation span.
    public init(
        name: String,
        controllerIdentity: String,
        attributes: [String: Any]? = nil
    ) {
        self.name = name
        self.controllerIdentity = controllerIdentity
        self.attributes = attributes
    }
}
