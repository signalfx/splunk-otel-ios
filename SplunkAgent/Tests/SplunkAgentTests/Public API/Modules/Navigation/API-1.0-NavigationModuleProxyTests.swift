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

import SplunkNavigation
import XCTest

@testable import SplunkAgent

final class NavigationAPI10ModuleProxyTests: XCTestCase {

    // MARK: - Private

    private var module: SplunkNavigation.Navigation?
    private var moduleProxy: SplunkAgent.Navigation?


    // MARK: - Tests lifecycle

    override func setUp() {
        super.setUp()

        module = SplunkNavigation.Navigation()

        if let module {
            moduleProxy = SplunkAgent.Navigation(for: module)
        }
    }

    override func tearDown() {
        super.tearDown()

        module = nil
        moduleProxy = nil
    }


    // MARK: - Preferences

    func testPreferences() throws {
        let moduleProxy = try XCTUnwrap(moduleProxy)

        let preferences = NavigationPreferences()
            .enableAutomatedTracking(true)

        // Set prepared preferences
        moduleProxy.preferences = preferences
        moduleProxy.preferences(preferences)

        // Codable conformance
        let readPreferences = moduleProxy.preferences
        let encodedPreferences = try? JSONEncoder().encode(readPreferences as? NavigationPreferences)
        XCTAssertNotNil(encodedPreferences)

        if let encodedPreferences {
            XCTAssertNoThrow(
                try JSONDecoder().decode(NavigationPreferences.self, from: encodedPreferences)
            )
        }
    }


    // MARK: - State

    func testState() throws {
        let moduleProxy = try XCTUnwrap(moduleProxy)
        let state = moduleProxy.state

        // Properties with default module configuration (READ)
        let defaultAutomatedTracking = state.isAutomatedTrackingEnabled
        XCTAssertNotNil(state.isAutomatedTrackingEnabled)
        XCTAssertFalse(defaultAutomatedTracking)
    }


    // MARK: - Manual detection

    func testTracking() throws {
        let moduleProxy = try XCTUnwrap(moduleProxy)
        XCTAssertNotNil(moduleProxy.track(screen: "Test"))
    }
}
