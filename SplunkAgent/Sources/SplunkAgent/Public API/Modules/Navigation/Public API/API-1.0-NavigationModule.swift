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

/// Defines a public API for the Navigation module.
public protocol NavigationModule: ObservableObject {

    // MARK: - Preferences

    /// An object that holds preferred settings for the module.
    var preferences: NavigationModulePreferences { get set }

    /// Sets preferred settings for the module.
    ///
    /// - Parameter preferences: The preferred settings for the module.
    ///
    /// - Returns: The actual `Navigation` instance.
    @discardableResult func preferences(_ preferences: NavigationModulePreferences) -> any NavigationModule


    // MARK: - State

    /// An object that reflects the current state and settings used for the module.
    var state: NavigationModuleState { get }


    // MARK: - Manual detection

    /// Sets a manual screen name. This setting is valid until a new name is set.
    ///
    /// - Parameter name: The name to be tracked as the screen name until being changed.
    ///
    /// - Returns: The actual `Navigation` instance.
    ///
    /// - Note: The set value is not linked to any specific UI element.
    @discardableResult func track(screen name: String) -> any NavigationModule
}
