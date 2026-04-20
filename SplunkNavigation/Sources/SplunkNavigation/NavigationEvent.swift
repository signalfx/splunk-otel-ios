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
///
/// This type is a class to support Objective-C interoperability.
@objc(SPLKNavigationEvent)
public final class NavigationEvent: NSObject {

    // MARK: - Public

    /// The screen name to use for this navigation event.
    ///
    /// This value is set as the `navigation.name` and `screen.name` span attributes.
    @objc
    public let name: String

    /// String representation of the tracked view controller identity.
    ///
    /// Objective-C consumers should use this property. Swift consumers can use
    /// ``controllerIdentifier`` for type-safe identity comparison.
    @objc
    public let controllerIdentity: String

    /// Identifier of the tracked view controller.
    ///
    /// Available when the event was created from Swift using the
    /// ``init(name:controllerIdentifier:attributes:)`` initializer.
    /// This is `nil` when the event was created via the Objective-C initializer.
    public let controllerIdentifier: ObjectIdentifier?

    /// Custom attributes to include in the navigation span.
    ///
    /// Use this to enrich navigation spans with application-specific metadata
    /// (e.g., content identifiers, feature flags, or section names).
    @objc
    public let attributes: [String: Any]?


    // MARK: - Initialization

    private init(
        name: String,
        controllerIdentity: String,
        controllerIdentifier: ObjectIdentifier?,
        attributes: [String: Any]?
    ) {
        self.name = name
        self.controllerIdentity = controllerIdentity
        self.controllerIdentifier = controllerIdentifier
        self.attributes = attributes
    }

    /// Creates a navigation event with a Swift `ObjectIdentifier`.
    ///
    /// - Parameters:
    ///   - name: The screen name for this navigation event.
    ///   - controllerIdentifier: The `ObjectIdentifier` of the tracked view controller.
    ///   - attributes: Optional custom attributes to include in the navigation span.
    public convenience init(
        name: String,
        controllerIdentifier: ObjectIdentifier,
        attributes: [String: Any]? = nil
    ) {
        self.init(
            name: name,
            controllerIdentity: String(describing: controllerIdentifier),
            controllerIdentifier: controllerIdentifier,
            attributes: attributes
        )
    }

    /// Creates a navigation event using a string identity.
    ///
    /// Use this initializer from Objective-C where `ObjectIdentifier` is not available.
    ///
    /// - Parameters:
    ///   - name: The screen name for this navigation event.
    ///   - controllerIdentity: String representation of the view controller identity.
    ///   - attributes: Optional custom attributes to include in the navigation span.
    @objc(initWithName:controllerIdentity:attributes:)
    public convenience init(
        name: String,
        controllerIdentity: String,
        attributes: [String: Any]? = nil
    ) {
        self.init(
            name: name,
            controllerIdentity: controllerIdentity,
            controllerIdentifier: nil,
            attributes: attributes
        )
    }
}
