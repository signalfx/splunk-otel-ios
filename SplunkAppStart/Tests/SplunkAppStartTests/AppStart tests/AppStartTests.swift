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
        appStart.processStartTimestamp = Date()
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
        appStart.processStartTimestamp = Date()
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

    /// Tests that when the app is launched in background (backgroundLaunchDetected = true),
    /// a warm start is correctly reported.
    ///
    /// Note: We manually set `backgroundLaunchDetected = true` because UIApplication.shared.applicationState
    /// cannot be mocked in unit tests. In production, this flag is set automatically in the
    /// `willEnterForegroundNotification` handler when `applicationState == .background` or when
    /// more than 10 seconds have passed since `didFinishLaunching`.
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

    /// Tests the timing-based background launch detection.
    /// This simulates an app that:
    /// 1. Starts in background (didFinishLaunching fires more than 10 seconds ago)
    /// 2. Stays in background for a while
    /// 3. User brings app to foreground (willEnterForeground, didBecomeActive fire)
    ///
    /// The backgroundLaunchDetected flag should be automatically set to true
    /// because more than 10 seconds have passed since didFinishLaunching,
    /// resulting in a warm start instead of a cold start with hours-long duration.
    func testBackgroundLaunchDetectedByTiming() throws {
        let destination = DebugDestination()

        let appStart = AppStart()
        appStart.destination = destination
        appStart.install(with: nil, remoteConfiguration: nil)

        // Simulate didFinishLaunching happened more than 10 seconds ago
        // (app was launched in background and stayed there)
        appStart.didFinishLaunchingTimestamp = Date().addingTimeInterval(-15.0)

        // Now simulate user bringing app to foreground
        // The willEnterForeground handler should detect this as a background launch
        // because more than 10 seconds have passed since didFinishLaunching
        simulateWarmStartNotifications()

        // Verify backgroundLaunchDetected was set to true by the timing check
        XCTAssertTrue(appStart.backgroundLaunchDetected == true, "backgroundLaunchDetected should be true due to timing check")

        // Should be warm start, NOT cold start
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

        try checkDeterminedType(.cold, in: destination)
    }

    func testManualTrackWithFullParameters() throws {
        let destination = DebugDestination()

        let appStart = AppStart()
        appStart.processStartTimestamp = Date()
        appStart.destination = destination

        appStart.startDetection()

        let didFinishLaunching = Date()
        let willEnterForeground = Date()
        let didBecomeActive = Date()

        appStart.track(didBecomeActive: didBecomeActive, didFinishLaunching: didFinishLaunching, willEnterForeground: willEnterForeground)

        // Check type and dates
        try checkDeterminedType(.cold, in: destination)
        try checkDates(in: destination)
    }

    func testManualTrackWithMinimumParameters() throws {
        let destination = DebugDestination()

        let appStart = AppStart()
        appStart.processStartTimestamp = Date()
        appStart.destination = destination

        appStart.startDetection()

        let didBecomeActive = Date()

        appStart.track(didBecomeActive: didBecomeActive, didFinishLaunching: nil, willEnterForeground: nil)

        // Check type and dates
        try checkDeterminedType(.cold, in: destination)
        try checkDates(in: destination)
    }
}
