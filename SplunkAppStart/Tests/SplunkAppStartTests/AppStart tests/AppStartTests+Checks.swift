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

import XCTest

@testable import SplunkAppStart

extension AppStartTests {
    func checkDeterminedType(_ checkedType: AppStartType, in destination: DebugDestination) throws {
        let storedAppStart = try XCTUnwrap(destination.storedAppStart)

        XCTAssertEqual(storedAppStart.type, checkedType)

        let duration = storedAppStart.end.timeIntervalSince(storedAppStart.start)
        XCTAssertGreaterThan(duration, 0)
    }

    func checkDates(in destination: DebugDestination) throws {
        let storedAppStart = try XCTUnwrap(destination.storedAppStart)

        let timeInterval = storedAppStart.end.timeIntervalSince(storedAppStart.start)
        XCTAssertGreaterThan(timeInterval, 0)
    }

    func checkNotDeterminedType(in destination: DebugDestination) throws {
        XCTAssertTrue(destination.storedAppStart == nil)
    }
}
