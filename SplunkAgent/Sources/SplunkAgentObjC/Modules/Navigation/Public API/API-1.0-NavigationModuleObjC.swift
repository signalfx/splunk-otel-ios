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

import Foundation
import SplunkAgent

/// The class implements a public API for the Navigation module.
@objc(SPLKNavigationModule)
public final class NavigationModuleObjC: NSObject {

    // MARK: - Internal

    private unowned let owner: SplunkRumObjC


    // MARK: - Preferences

    /// An object that holds preferred settings for the module, a ``NavigationModulePreferencesObjc`` instance.
    @objc
    public var preferences: NavigationModulePreferencesObjC {
        get {
            let preferences = NavigationModulePreferencesObjC(enableAutomatedTracking: owner.agent.navigation.preferences.enableAutomatedTracking ?? false)
            preferences.owner = owner
            return preferences
        }

        set {
            newValue.owner = owner
            owner.agent.navigation.preferences = NavigationPreferences(enableAutomatedTracking: newValue.enableAutomatedTracking)
        }
    }


    // MARK: - State

    /// An object that reflects the current state and settings used for the module, a ``NavigationModuleStateObjC`` instance.
    @objc
    public var state: NavigationModuleStateObjC {
        NavigationModuleStateObjC(for: owner)
    }


    // MARK: - Manual detection

    /// Sets a manual screen name. This setting is valid until a new name is set.
    ///
    /// - Parameter name: The name to be tracked as the screen name until being changed.
    ///
    /// - Returns: The actual ``NavigationModuleObjC`` instance.
    ///
    /// - Note: The set value is not linked to any specific UI element.
    @discardableResult
    @objc(trackScreen:)
    public func track(screen name: String) -> NavigationModuleObjC {
        owner.agent.navigation.track(screen: name)

        return self
    }


    // MARK: - Initialization

    init(for owner: SplunkRumObjC) {
        self.owner = owner
    }
}
