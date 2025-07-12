//
/*
Copyright 2025 Splunk Inc.

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

/// An interface for configuring the behavior of the navigation module.
public protocol NavigationModulePreferences {

    // MARK: - Automated tracking

    /// A Boolean value that enables or disables automatic tracking of view controller transitions.
    ///
    /// If set to `true`, the module automatically creates screen name spans for view controller appearances.
    /// If `false`, you must track screen views manually using ``NavigationModule/track(screen:)``.
    /// A value of `nil` restores the default behavior.
    var enableAutomatedTracking: Bool? { get set }

    /// Enables or disables automatic tracking of view controller transitions.
    ///
    /// - Parameter enable: A `Bool` to enable or disable tracking. Pass `nil` to restore the default behavior.
    /// - Returns: The updated preferences object to allow for chaining.
    @discardableResult func enableAutomatedTracking(_ enable: Bool?) -> any NavigationModulePreferences


    // MARK: - Convenience init

    /// Initializes a new preferences object.
    ///
    /// - Parameter enableAutomatedTracking: A `Bool` to enable or disable automatic tracking.
    ///   Pass `nil` to use the default setting.
    ///
    /// ### Example ###
    /// ```
    /// // Create preferences to disable automatic screen tracking
    /// let navPrefs = ConcreteNavigationPreferences(enableAutomatedTracking: false)
    /// SplunkRum.shared.navigation.preferences(navPrefs)
    /// ```
    init(enableAutomatedTracking: Bool?)
}