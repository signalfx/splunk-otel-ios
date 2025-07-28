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

@testable import SplunkNavigation
import XCTest

final class NavigationTests: XCTestCase {

    // MARK: - Private

    private let navigationModule = Navigation()


    // MARK: - Basic logic

    func testInitialization() throws {
        XCTAssertNotNil(navigationModule)
    }


    // MARK: - Business logic

    func testProperties() throws {
        // Properties with default module configuration (READ)
        let preferences = navigationModule.preferences
        let state = navigationModule.state

        // Properties (WRITE)
        let customPreferences = Preferences(
            enableAutomatedTracking: true
        )
        navigationModule.preferences = customPreferences


        // Check existency of basic properties
        XCTAssertNotNil(preferences)
        XCTAssertNotNil(state)

        // Module preferences should be updated
        let modulePreferences = navigationModule.preferences
        XCTAssertEqual(modulePreferences.enableAutomatedTracking, true)
    }

    func testStateUpdates() throws {
        let state = navigationModule.state
        let defaultTrackingState = state.isAutomatedTrackingEnabled


        // Perform preference property updates
        let preferences = navigationModule.preferences
        preferences.enableAutomatedTracking = true

        let updatedTrackingState = state.isAutomatedTrackingEnabled
        preferences.enableAutomatedTracking = false


        let finalTrackingState = state.isAutomatedTrackingEnabled
        XCTAssertFalse(defaultTrackingState)
        XCTAssertTrue(updatedTrackingState)
        XCTAssertFalse(finalTrackingState)
    }

    func testTracking() async throws {
        let customName = "Test Screen"
        navigationModule.track(screen: customName)

        let _ = await navigationModule.model.screenName
        // XCTAssertEqual(screenName, customName)
    }
}
