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

import XCTest
@testable import SplunkNavigation

final class PreferencesTests: XCTestCase {

    // MARK: - Private

    private let preferences = Preferences()


    // MARK: - Basic logic

    func testInitialization() throws {
        // Perform initialization (as standalone object)
        let configuredPreferences = Preferences(
            enableAutomatedTracking: true
        )

        // Check default values
        XCTAssertNotNil(preferences)
        XCTAssertNil(preferences.enableAutomatedTracking)

        XCTAssertNotNil(configuredPreferences)
        XCTAssertNotNil(configuredPreferences.enableAutomatedTracking)

        let enableAutomatedTracking = try XCTUnwrap(configuredPreferences.enableAutomatedTracking)
        XCTAssertTrue(enableAutomatedTracking)
    }

    func testInitializationForModule() {
        // Prepare Navigation module instance
        let navigationModule = Navigation()

        // Initialize preferences with module
        let preferences = Preferences(for: navigationModule)

        // Check default values
        XCTAssertNotNil(preferences)
        XCTAssertNil(preferences.enableAutomatedTracking)
    }


    // MARK: - Business logic

    func testProperties() throws {
        // Properties with default module configuration (READ)
        let defaultAutomatedTracking = preferences.enableAutomatedTracking

        // Properties with custom module configuration (WRITE)
        preferences.enableAutomatedTracking = true
        let customAutomatedTracking = preferences.enableAutomatedTracking


        XCTAssertNil(defaultAutomatedTracking)
        XCTAssertNotNil(customAutomatedTracking)

        let customAutomatedTrackingValue = try XCTUnwrap(customAutomatedTracking)
        XCTAssertTrue(customAutomatedTrackingValue)
    }

    func testPropertiesMethods() throws {
        let returnObject =
            preferences
            .enableAutomatedTracking(true)


        // Method should return the same object
        XCTAssertNotNil(returnObject)
        XCTAssert(returnObject === preferences)

        // The object should be updated
        let enableAutomatedTracking = try XCTUnwrap(preferences.enableAutomatedTracking)
        XCTAssertTrue(enableAutomatedTracking)
    }
}
