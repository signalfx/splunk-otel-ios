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

/// The class implementing AppStart public API in non-operational mode.
final class AppStartNonOperational: AppStartModule {

    // MARK: - Private

    private let logger: DefaultLogAgent


    // MARK: - Initialization

    init() {
        logger = DefaultLogAgent(
            poolName: PackageIdentifier.nonOperationalInstance(),
            category: "AppStart"
        )
    }


    // MARK: - Logger

    func logAccess(toApi named: String) {
        logger.log(level: .notice) {
            """
            Attempt to access the API of a non-operational AppStart module. \n
            API: `\(named)`
            """
        }
    }
}
