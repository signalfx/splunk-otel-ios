//
/*
Copyright 2024 Splunk Inc.

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

import SplunkNavigation
import XCTest

final class RuntimeStateTests: XCTestCase {

    // MARK: - Business logic

    func testProperties() {
        // Prepare Navigation module instance
        let navigationModule = Navigation()
        let state = navigationModule.state

        // Properties with default module configuration (READ)
        let defaultAutomatedTracking = state.isAutomatedTrackingEnabled
        XCTAssertFalse(defaultAutomatedTracking)

        // Properties with custom module configuration (READ)
        navigationModule.preferences.enableAutomatedTracking = true
        let customAutomatedTracking = state.isAutomatedTrackingEnabled
        XCTAssertTrue(customAutomatedTracking)
    }
}
