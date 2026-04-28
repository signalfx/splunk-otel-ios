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
///     NavigationEvent(name: friendlyName(for: typeName))
/// }
/// ```
///
/// **Add custom attributes to the `app.ui.navigation` span:**
///
/// ```swift
/// func onViewController(
///     typeName: String,
///     controllerIdentity: String
/// ) -> NavigationEvent? {
///     NavigationEvent(
///         name: typeName,
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
///     shouldIgnore(typeName) ? nil : NavigationEvent(name: typeName)
/// }
/// ```
///
/// Assign your processor to
/// ``NavigationConfiguration/navigationEventProcessor`` before starting the agent.
///
/// ## Threading
///
/// The callback may be invoked from a background task. The protocol requires
/// `Sendable` conformance.
public protocol NavigationEventProcessor: Sendable {

    // MARK: - Processor methods

    /// Called for each detected `UIViewController` navigation event.
    ///
    /// Return a ``NavigationEvent`` to allow the navigation — potentially with a
    /// transformed name or additional attributes — or return `nil` to suppress it.
    ///
    /// - Parameters:
    ///   - typeName: The view controller's class name. The SDK strips the
    ///     application module prefix before invoking this method, so your
    ///     callback will receive `"DetailViewController"` as the value of
    ///     this parameter rather than `"MyApp.DetailViewController"`.
    ///   - controllerIdentity: An opaque, SDK-generated string identifying the
    ///     view controller instance. Unique among live instances, stable for the
    ///     lifetime of the instance, not persisted across launches. See the
    ///     public ``NavigationModuleEventProcessor`` docs for full semantics.
    ///
    /// - Returns: A navigation event describing the screen, or `nil` to suppress.
    func onViewController(typeName: String, controllerIdentity: String) -> NavigationEvent?
}
