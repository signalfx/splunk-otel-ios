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

/// The user preferences object represents the preferred settings related to the user.
@objc(SPLKUserPreferences)
public final class UserPreferencesObjC: NSObject {

    // MARK: - Internal

    private unowned let owner: SplunkRumObjC


    // MARK: - User identification

    /// The required tracking mode for user identification.
    ///
    /// A `NSNumber` which value can be mapped to the `SPLKUserTrackingMode` constants.
    @objc
    public var trackingMode: NSNumber {
        get {
            let mode = owner.agent.user.preferences.trackingMode

            return UserTrackingModeObjC.value(for: mode)
        }
        set {
            let mode = UserTrackingModeObjC.userTrackingMode(for: newValue)
            owner.agent.user.preferences.trackingMode = mode
        }
    }


    // MARK: - Initialization

    init(for owner: SplunkRumObjC) {
        self.owner = owner
    }
}
