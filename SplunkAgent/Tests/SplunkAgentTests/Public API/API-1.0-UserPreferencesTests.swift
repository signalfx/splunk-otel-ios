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

import SplunkAgent
import XCTest

final class API10UserPreferencesTests: XCTestCase {

    // MARK: - API Tests

    func testPreferences() throws {
        // Touch `UserPreferences` property
        let agent = try AgentTestBuilder.buildDefault()
        let userPreferences = agent.user.preferences
        XCTAssertNotNil(userPreferences)


        // Properties (READ)
        let initialTrackingMode = userPreferences.trackingMode
        XCTAssertEqual(initialTrackingMode, UserTrackingMode.noTracking)


        // Properties (WRITE)
        userPreferences.trackingMode = .default
        XCTAssertEqual(userPreferences.trackingMode, UserTrackingMode.noTracking)

        userPreferences.trackingMode = .anonymousTracking
        XCTAssertEqual(userPreferences.trackingMode, UserTrackingMode.anonymousTracking)

        userPreferences.trackingMode(.noTracking)
        XCTAssertEqual(userPreferences.trackingMode, UserTrackingMode.noTracking)
    }
}
