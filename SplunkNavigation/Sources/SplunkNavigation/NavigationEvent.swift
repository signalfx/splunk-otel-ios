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

    /// A normalized screen name.
    @objc
    public var screenName: String

    /// Additional attributes associated with navigation.
    @objc
    public var attributes: [String: Any]?

    /// String representation of the tracked UI identity.
    @objc
    public let controllerIdentity: String

    /// Identifier of the tracked UI object used by Swift consumers.
    public let controllerIdentifier: ObjectIdentifier


    // MARK: - Initialization

    /// Creates a navigation event.
    ///
    /// - Parameters:
    ///   - screenName: A normalized screen name.
    ///   - controllerIdentifier: Identifier of the tracked UI object.
    ///   - attributes: Additional event attributes.
    public init(
        screenName: String,
        controllerIdentifier: ObjectIdentifier,
        attributes: [String: Any]? = nil
    ) {
        self.screenName = screenName
        self.controllerIdentifier = controllerIdentifier
        controllerIdentity = String(describing: controllerIdentifier)
        self.attributes = attributes
    }
}
