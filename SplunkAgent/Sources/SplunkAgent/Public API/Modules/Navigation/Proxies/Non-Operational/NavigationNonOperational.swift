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
internal import SplunkCommon

/// The class implementing Navigation public API in non-operational mode.
///
/// This is especially the case when the module is stopped by remote configuration,
/// but we still need to keep the API available to the user.
final class NavigationNonOperational: NavigationModule {

    // MARK: - Private

    private let logger: DefaultLogAgent


    // MARK: - Preferences

    var preferences: any NavigationModulePreferences {
        get {
            logAccess(toApi: #function)

            return NavigationPreferences()
        }

        // swiftlint:disable unused_setter_value
        set {
            logAccess(toApi: #function)
        }
        // swiftlint:enable unused_setter_value
    }

    @discardableResult
    func preferences(_: any NavigationModulePreferences) -> any NavigationModule {
        logAccess(toApi: #function)

        return self
    }


    // MARK: - State

    let state: any NavigationModuleState


    // MARK: - Initialization

    init() {
        logger = DefaultLogAgent(
            poolName: PackageIdentifier.nonOperationalInstance(),
            category: "SessionReplay"
        )

        // Build "dummy" Navigation module
        state = NavigationNonOperationalState()
    }


    // MARK: - Logger

    func logAccess(toApi named: String) {
        logger.log(level: .notice) {
            """
            Attempt to access the API of a non-operational Navigation module. \n
            API: `\(named)`
            """
        }
    }
}
