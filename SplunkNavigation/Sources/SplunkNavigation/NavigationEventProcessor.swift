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

/// A processor that intercepts automated navigation events before they produce spans.
///
/// Implement this protocol to customize how detected `UIViewController` transitions
/// are named, enriched, or filtered. The processor is called once per automated
/// navigation event; manual ``Navigation/track(screen:)`` calls bypass it.
///
/// **Rename a screen:**
///
/// ```swift
/// func onViewController(
///     typeName: String,
///     controllerIdentity: String
/// ) -> NavigationEvent? {
///     NavigationEvent(
///         name: friendlyName(for: typeName),
///         controllerIdentity: controllerIdentity
///     )
/// }
/// ```
///
/// **Add custom attributes to the navigation span:**
///
/// ```swift
/// func onViewController(
///     typeName: String,
///     controllerIdentity: String
/// ) -> NavigationEvent? {
///     NavigationEvent(
///         name: typeName,
///         controllerIdentity: controllerIdentity,
///         attributes: ["app.section": section(for: typeName)]
///     )
/// }
/// ```
///
/// **Suppress an event entirely** by returning `nil`:
///
/// ```swift
/// func onViewController(
///     typeName: String,
///     controllerIdentity: String
/// ) -> NavigationEvent? {
///     shouldIgnore(typeName) ? nil : NavigationEvent(
///         name: typeName,
///         controllerIdentity: controllerIdentity
///     )
/// }
/// ```
///
/// Assign your processor to
/// ``NavigationConfiguration/navigationEventProcessor`` before starting the agent.
@objc(SPLKNavigationEventProcessor)
public protocol NavigationEventProcessor {

    // MARK: - Processor methods

    /// Called for each detected `UIViewController` navigation event.
    ///
    /// Return a ``NavigationEvent`` to allow the navigation — potentially with a
    /// transformed name or additional attributes — or return `nil` to suppress it.
    ///
    /// - Parameters:
    ///   - typeName: The sanitized controller type name (module prefix stripped).
    ///   - controllerIdentity: String representation of the controller's object identifier.
    ///
    /// - Returns: A navigation event describing the screen, or `nil` to suppress.
    @objc(onViewControllerWithTypeName:controllerIdentity:)
    func onViewController(typeName: String, controllerIdentity: String) -> NavigationEvent?
}

/// The default processor that passes navigation events through unchanged.
///
/// This processor returns the sanitized controller type name as the screen name
/// with no additional attributes. It is used automatically when no custom
/// ``NavigationEventProcessor`` is configured.
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
