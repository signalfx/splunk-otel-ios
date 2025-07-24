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

/// A configuration object representing properties of the Agent's `SPLKUser`.
@objc(SPLKUserConfiguration)
public final class UserConfigurationObjC: NSObject {

    // MARK: - Private

    private var configuration: UserConfiguration


    // MARK: - Public API

    /// Sets the preferred tracking mode for user identification.
    ///
    /// Defaults to `SPLKUserTrackingMode.noTracking`.
    ///
    /// A `NSNumber` which value can be mapped to the `SPLKUserTrackingMode` constants.
    @objc
    public var trackingMode: NSNumber {
        get {
            UserTrackingModeObjC.value(for: configuration.trackingMode)
        }
        set {
            let mode = UserTrackingModeObjC.userTrackingMode(for: newValue)
            configuration.trackingMode = mode
        }
    }


    // MARK: - Initialization

    /// Default empty constructor.
    ///
    /// Initializes the configuration object's properties with default values.
    @objc
    public override convenience init() {
        let userConfiguration = UserConfiguration()

        self.init(for: userConfiguration)
    }

    /// Initializes the configuration object.
    ///
    /// - Parameter trackingMode: The preferred `SPLKUserTrackingMode`.
    @objc
    public convenience init(trackingMode: NSNumber) {
        let userConfiguration = UserConfiguration(
            trackingMode: UserTrackingModeObjC.userTrackingMode(for: trackingMode)
        )

        self.init(for: userConfiguration)
    }


    // MARK: - Conversion utils

    init(for userConfiguration: UserConfiguration) {
        // Initialize according to the native Swift variant
        configuration = userConfiguration
    }

    func userConfiguration() -> UserConfiguration {
        // We return a native variant for Swift language
        configuration
    }
}
