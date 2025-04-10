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

final class AppStartTests: XCTestCase {

    func testProcessStart() throws {
        let appStart = AppStart()
        let processStart = try XCTUnwrap(appStart.processStartTime())

        let duration = Date().timeIntervalSince(processStart)
        XCTAssert(duration > 0.0)
        XCTAssert(duration < 60.0)
    }

    func testStart() throws {
        let destination = DebugDestination()

        let appStart = AppStart()
        appStart.destination = destination

        appStart.startDetection()

        simulateColdStartNotifications()

        // Check type and dates
        try checkDeterminedType(.cold, in: destination)
        try checkDates(in: destination)
    }

    func testStop() throws {
        let destination = DebugDestination()

        let appStart = AppStart()
        appStart.destination = destination

        appStart.startDetection()
        appStart.stopDetection()

        simulateColdStartNotifications()

        // Check type and dates
        try checkNotDeterminedType(in: destination)
    }

    func testColdStart() throws {
        let destination = DebugDestination()

        let appStart = AppStart()
        appStart.destination = destination
        appStart.install(with: nil, remoteConfiguration: nil)

        simulateColdStartNotifications()

        // Check type and dates
        try checkDeterminedType(.cold, in: destination)
        try checkDates(in: destination)
        
        // Check events
        let events = try XCTUnwrap(destination.storedAppStart?.events)
        XCTAssertTrue(events.count >= 4)

        // Check event sorting
        var testedDate = Date(timeIntervalSince1970: 0)
        for event in events {
            XCTAssertTrue(event.timestamp > testedDate)
            testedDate = event.timestamp
        }
    }

    func testPrewarmStart() throws {
        let destination = DebugDestination()

        let appStart = AppStart()
        appStart.destination = destination
        appStart.install(with: nil, remoteConfiguration: nil)
        appStart.prewarmDetected = true

        simulateWarmStartNotifications()

        // Check type and dates
        try checkDeterminedType(.warm, in: destination)
        try checkDates(in: destination)
    }

    func testBackgroundStart() throws {
        let destination = DebugDestination()

        let appStart = AppStart()
        appStart.backgroundLaunchDetected = true
        appStart.destination = destination
        appStart.install(with: nil, remoteConfiguration: nil)

        simulateWarmStartNotifications()

        // Check type and dates
        try checkDeterminedType(.warm, in: destination)
        try checkDates(in: destination)
    }

    func testHotStart() throws {
        let destination = DebugDestination()

        let appStart = AppStart()
        appStart.destination = destination
        appStart.install(with: nil, remoteConfiguration: nil)

        simulateHotStartNotifications()

        // Check type and dates
        try checkDeterminedType(.hot, in: destination)
        try checkDates(in: destination)
    }

    func testNoDidFinishLaunching() throws {
        let destination = DebugDestination()

        let appStart = AppStart()
        appStart.destination = destination
        appStart.install(with: nil, remoteConfiguration: nil)

        simulateStartNotificationsWithNoDidFinishLaunching()

        try checkNotDeterminedType(in: destination)
    }
}
