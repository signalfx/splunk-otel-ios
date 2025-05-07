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

internal import CiscoLogger
import SplunkCommon

/// The navigation module detects and tracks navigation in the application.
public final class Navigation {

    // MARK: - Private

    // Internal Logger
    let logger = DefaultLogAgent(poolName: PackageIdentifier.instance(), category: "Navigation")

    // Currently set custom name
    var screenName: String?


    // MARK: - Preferences

    /// An object that holds preferred settings for the module.
    public var preferences = Preferences() {
        didSet {
            preferences.module = self
            update()
        }
    }


    // MARK: - State

    /// An object reflects the current state and settings used for the module.
    public let state = RuntimeState()


    // MARK: - Initialization

    // Module protocol conformance
    public required init() {
        preferences.module = self
    }


    // MARK: - Instrumentation

    /// Starts detection and processing of navigation.
    func startDetection() {
        logger.log {
            "Navigation module started."
        }
    }

    /// Updates the module to the desired state according to the current preferences.
    func update() {
        // Update module
        // ...

        // Update state
        state.isAutomatedTrackingEnabled = preferences.enableAutomatedTracking ?? false
    }
}
