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
/// Returned by ``NavigationEventProcessorObjC/onViewController(typeName:controllerIdentity:)``
/// to describe how a detected screen transition should be recorded. The ``name`` becomes the
/// `navigation.name` span attribute, and any ``attributes`` are added to the `app.ui.navigation` span.
@objc(SPLKNavigationEvent)
public final class NavigationEventObjC: NSObject {

    // MARK: - Public

    /// The screen name to use for this navigation event.
    ///
    /// This value is set as the `navigation.name` and `screen.name` span attributes.
    @objc
    public let name: String

    /// Custom attributes to include in the `app.ui.navigation` span.
    ///
    /// Use this to enrich the `app.ui.navigation` span with application-specific metadata
    /// (e.g., content identifiers, feature flags, or section names).
    /// Supported value types: `NSString`, `NSNumber` (integer, double, boolean), and arrays of those types.
    @objc
    public let attributes: NSDictionary?


    // MARK: - Initialization

    /// Creates a navigation event.
    ///
    /// - Parameters:
    ///   - name: The screen name for this navigation event.
    ///   - attributes: Optional custom attributes to include in the `app.ui.navigation` span.
    @objc(initWithName:attributes:)
    public init(
        name: String,
        attributes: NSDictionary? = nil
    ) {
        self.name = name
        self.attributes = attributes
    }

    /// Creates a navigation event with no custom attributes.
    ///
    /// - Parameter name: The screen name for this navigation event.
    @objc(initWithName:)
    public convenience init(name: String) {
        self.init(name: name, attributes: nil)
    }
}
