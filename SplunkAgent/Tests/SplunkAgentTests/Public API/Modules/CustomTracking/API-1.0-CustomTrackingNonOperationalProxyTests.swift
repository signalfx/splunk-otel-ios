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

@testable import SplunkAgent
import XCTest

final class CustomTrackingAPI10NoOpProxyTests: XCTestCase {

    // MARK: - Private

    let moduleProxy = CustomTrackingTestBuilder.buildNonOperational()


    // MARK: - Preferences

    func testPreferences() throws {
        // FIXME: use correct configuration property
        let preferences = CustomTrackingPreferences()
            .enableAutomatedTracking(true)

        // Set prepared preferences
        moduleProxy.preferences = preferences
        moduleProxy.preferences(preferences)

        // Codable conformance
        let readPreferences = moduleProxy.preferences
        let encodedPreferences = try? JSONEncoder().encode(readPreferences as? CustomTrackingPreferences)
        XCTAssertNotNil(encodedPreferences)

        if let encodedPreferences {
            XCTAssertNoThrow(
                try JSONDecoder().decode(CustomTrackingPreferences.self, from: encodedPreferences)
            )
        }
    }


    // MARK: - State

    func testState() throws {
        let state = moduleProxy.state

        // Properties with default module configuration (READ)
        // FIXME
        let defaultAutomatedTracking = state.isAutomatedTrackingEnabled
        XCTAssertNotNil(state.isAutomatedTrackingEnabled)
        XCTAssertFalse(defaultAutomatedTracking)
    }


    // MARK: - Manual detection

    // FIXME
    func testTracking() throws {
        XCTAssertNotNil(moduleProxy.track(screen: "Test"))
    }
}
