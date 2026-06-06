//
/*
Copyright 2026 Splunk Inc.

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

import SplunkLifecycle
import XCTest

final class LifecycleActionTests: XCTestCase {

    // MARK: - Raw values

    func testSupportedRawValues() {
        XCTAssertEqual(LifecycleAction(rawValue: "view_created"), .viewCreated)
        XCTAssertEqual(LifecycleAction(rawValue: "resumed"), .resumed)
        XCTAssertEqual(LifecycleAction(rawValue: "stopped"), .stopped)
    }

    func testUnsupportedRawValuesReturnNil() {
        XCTAssertNil(LifecycleAction(rawValue: "started"))
        XCTAssertNil(LifecycleAction(rawValue: "paused"))
        XCTAssertNil(LifecycleAction(rawValue: "destroyed"))
        XCTAssertNil(LifecycleAction(rawValue: "attached"))
        XCTAssertNil(LifecycleAction(rawValue: "detached"))
        XCTAssertNil(LifecycleAction(rawValue: "view_destroyed"))
        XCTAssertNil(LifecycleAction(rawValue: ""))
        XCTAssertNil(LifecycleAction(rawValue: "RESUMED"))
    }

    func testMainLifecycleEventsContainsOnlySupportedFirstScopeActions() {
        XCTAssertEqual(
            LifecycleAction.mainLifecycleEvents,
            [.viewCreated, .resumed, .stopped]
        )
    }
}
