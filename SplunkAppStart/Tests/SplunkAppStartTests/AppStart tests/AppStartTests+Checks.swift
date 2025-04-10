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

@testable import SplunkAppStart
import XCTest

extension AppStartTests {
    func checkDeterminedType(_ checkedType: AppStartType, in destination: DebugDestination) throws {
        let storedAppStart = try XCTUnwrap(destination.storedAppStart)
        
        let type = try XCTUnwrap(storedAppStart.type)
        let startTime = try XCTUnwrap(storedAppStart.start)
        let endTime = try XCTUnwrap(storedAppStart.end)
        
        XCTAssertTrue(type == checkedType)
        
        let duration = endTime.timeIntervalSince(startTime)
        XCTAssertTrue(duration > 0.0)
        XCTAssertTrue(duration < 60.0)
    }

    func checkDates(in destination: DebugDestination) throws {
        let storedAppStart = try XCTUnwrap(destination.storedAppStart)
        
        let timeInterval = storedAppStart.end.timeIntervalSince(storedAppStart.start)
        XCTAssertTrue(timeInterval > 0.0)
        XCTAssertTrue(timeInterval < 60.0)
    }

    func checkNotDeterminedType(in destination: DebugDestination) throws {
        XCTAssertTrue(destination.storedAppStart == nil)
    }
}
