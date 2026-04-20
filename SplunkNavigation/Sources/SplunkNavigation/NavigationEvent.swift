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

/// A navigation event processed by ``NavigationEventProcessor``.
///
/// This model is class-based to support Objective-C interoperability.
@objc(SPLKNavigationEvent)
public final class NavigationEvent: NSObject {

    // MARK: - Public

    /// The navigation name for this event.
    @objc
    public let name: String

    /// String representation of the tracked UI identity.
    @objc
    public let controllerIdentity: String

    /// Identifier of the tracked UI object used by Swift consumers.
    ///
    /// This is `nil` when the event was created via the Objective-C initializer.
    public let controllerIdentifier: ObjectIdentifier?

    /// Additional attributes associated with navigation.
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

    /// Creates a navigation event.
    ///
    /// - Parameters:
    ///   - name: The navigation name for this event.
    ///   - controllerIdentifier: Identifier of the tracked UI object.
    ///   - attributes: Additional event attributes.
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
    /// This initializer is available for Objective-C consumers where `ObjectIdentifier` is not accessible.
    ///
    /// - Parameters:
    ///   - name: The navigation name for this event.
    ///   - controllerIdentity: String representation of the tracked UI identity.
    ///   - attributes: Additional event attributes.
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
