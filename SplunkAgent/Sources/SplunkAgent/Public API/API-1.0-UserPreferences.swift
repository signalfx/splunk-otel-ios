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

/// An object for managing user-specific preferences, such as the tracking mode.
public final class UserPreferences {

    // MARK: - Internal

    // The SplunkRum instance that owns these user preferences.
    private unowned let owner: SplunkRum


    // MARK: - Initialization

    /// Initializes the user preferences with its owning `SplunkRum` instance.
    init(for owner: SplunkRum) {
        self.owner = owner
    }
}


public extension UserPreferences {

    // MARK: - User identification

    /// The tracking mode that controls how the user is identified.
    ///
    /// See ``UserTrackingMode`` for available options.
    var trackingMode: UserTrackingMode {
        get {
            owner.currentUser.trackingMode
        }
        set {
            owner.currentUser.trackingMode = newValue
        }
    }

    /// Sets the tracking mode for user identification.
    ///
    /// - Parameter trackingMode: The tracking mode to apply.
    /// - Returns: The updated user preferences object.
    ///
    /// ### Example ###
    /// ```
    /// SplunkRum.user.preferences.trackingMode(.anonymous)
    /// ```
    @discardableResult func trackingMode(_ trackingMode: UserTrackingMode) -> UserPreferences {
        owner.currentUser.trackingMode = trackingMode

        return self
    }
}