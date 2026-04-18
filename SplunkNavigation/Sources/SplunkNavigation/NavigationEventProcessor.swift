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

/// Defines basic functionality for navigation event processors.
@objc(SPLKNavigationEventProcessor)
public protocol NavigationEventProcessor {

    // MARK: - Processor methods

    /// Processes and filters detected navigation events on `UIViewController` descendants.
    ///
    /// Return a ``NavigationEvent`` to allow the navigation (potentially with a transformed name
    /// or additional attributes), or return `nil` to suppress the event entirely.
    ///
    /// - Parameters:
    ///   - typeName: The name of the controller type associated with the navigation event.
    ///   - controllerIdentity: String representation of the controller's object identifier.
    ///
    /// - Returns: New navigation event or `nil` if this navigation should be ignored.
    @objc(onViewControllerWithTypeName:controllerIdentity:)
    func onViewController(typeName: String, controllerIdentity: String) -> NavigationEvent?
}

/// A pass-through processor used by default.
@objc(SPLKDefaultNavigationEventProcessor)
public final class DefaultNavigationEventProcessor: NSObject, NavigationEventProcessor {

    // MARK: - Initialization

    @objc
    override public init() {
        super.init()
    }


    // MARK: - Processor methods

    @objc(onViewControllerWithTypeName:controllerIdentity:)
    public func onViewController(typeName: String, controllerIdentity: String) -> NavigationEvent? {
        NavigationEvent(
            name: typeName,
            controllerIdentity: controllerIdentity,
            attributes: nil
        )
    }
}
