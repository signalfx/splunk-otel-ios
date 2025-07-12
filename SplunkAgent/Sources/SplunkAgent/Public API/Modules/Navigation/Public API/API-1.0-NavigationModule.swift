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

import Combine

/// An interface for tracking screen transitions and other navigation-related events.
///
/// This module can be configured to track navigation automatically or can be used to
/// track screen views manually.
public protocol NavigationModule: ObservableObject {

    // MARK: - Preferences

    /// The preferences that control the behavior of the navigation module.
    ///
    /// See ``NavigationModulePreferences`` for available options.
    var preferences: NavigationModulePreferences { get set }

    /// Sets the preferences for the navigation module.
    ///
    /// - Parameter preferences: The ``NavigationModulePreferences`` to apply.
    /// - Returns: The `NavigationModule` instance to allow for chaining.
    ///
    /// ### Example ###
    /// ```
    /// var navPrefs = NavigationModulePreferences()
    /// navPrefs.enableAutomatedTracking = false
    /// SplunkRum.shared.navigation.preferences(navPrefs)
    /// ```
    @discardableResult func preferences(_ preferences: NavigationModulePreferences) -> any NavigationModule


    // MARK: - State

    /// An object that reflects the current state of the navigation module.
    ///
    /// See ``NavigationModuleState`` for more details.
    var state: NavigationModuleState { get }


    // MARK: - Manual detection

    /// Manually tracks a screen view with a custom name.
    ///
    /// This name will be used for all subsequent screen-related spans until a new name is set.
    ///
    /// - Parameter name: The custom name for the screen.
    /// - Returns: The `NavigationModule` instance to allow for chaining.
    ///
    /// - Note: The screen name set via this method is not linked to any specific UI element.
    ///
    /// ### Example ###
    /// ```
    /// SplunkRum.shared.navigation.track(screen: "ProductDetailsView")
    /// ```
    @discardableResult func track(screen name: String) -> any NavigationModule
}