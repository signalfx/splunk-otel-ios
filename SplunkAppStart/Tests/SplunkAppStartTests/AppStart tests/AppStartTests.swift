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

@testable @_spi(SplunkInternal) import SplunkAppStart

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
        XCTAssertEqual(destination.storedAppStart?.end, didBecomeActive)
    }

    func testManualTrackWithIncompleteUnknownOriginDoesNotSend() throws {
        let destination = DebugDestination()

        let appStart = AppStart()
        appStart.processStartTimestamp = Date()
        appStart.destination = destination

        appStart.startDetection()

        let didBecomeActive = Date()

        appStart.track(didBecomeActive: didBecomeActive, didFinishLaunching: nil, willEnterForeground: nil)

        try checkNotDeterminedType(in: destination)
    }

    func testManualTrackWithForegroundOriginAndLongLaunchIsCold() throws {
        let destination = DebugDestination()
        let didBecomeActive = Date()
        let processStart = didBecomeActive.addingTimeInterval(-20.0)
        let didFinishLaunching = didBecomeActive.addingTimeInterval(-19.0)
        let willEnterForeground = didBecomeActive.addingTimeInterval(-1.0)

        let appStart = AppStart()
        appStart.processStartTimestamp = processStart
        appStart.destination = destination

        appStart.track(
            didBecomeActive: didBecomeActive,
            didFinishLaunching: didFinishLaunching,
            willEnterForeground: willEnterForeground,
            launchOrigin: .foreground
        )

        try checkDeterminedType(.cold, in: destination)
        XCTAssertEqual(destination.storedAppStart?.start, processStart)
        XCTAssertEqual(destination.storedAppStart?.end, didBecomeActive)
    }

    func testCompleteBackgroundSnapshotTracksAfterUIKitActivationAlreadyOccurred() throws {
        let destination = DebugDestination()
        let didBecomeActive = Date()
        let didFinishLaunching = didBecomeActive.addingTimeInterval(-5.0)
        let willEnterForeground = didBecomeActive.addingTimeInterval(-1.0)

        // These notifications occur before the native SDK starts listening, as they can when a
        // hybrid SDK is installed from JavaScript or Dart after the application becomes active.
        simulateColdStartNotifications()

        let appStart = AppStart()
        appStart.processStartTimestamp = didFinishLaunching.addingTimeInterval(-1.0)
        appStart.destination = destination
        appStart.startDetection()

        appStart.track(initialLifecycle: AppStartLifecycleSnapshot(
            launchOrigin: .background,
            didFinishLaunching: didFinishLaunching,
            willEnterForeground: willEnterForeground,
            didBecomeActive: didBecomeActive
        ))

        try checkDeterminedType(.warm, in: destination)
        XCTAssertEqual(destination.storedAppStart?.start, willEnterForeground)
        XCTAssertEqual(destination.storedAppStart?.end, didBecomeActive)
    }

    func testPartialBackgroundSnapshotCompletesWithNativeActivation() throws {
        let destination = DebugDestination()
        let didFinishLaunching = Date().addingTimeInterval(-5.0)
        let willEnterForeground = Date().addingTimeInterval(-1.0)

        let appStart = AppStart()
        appStart.destination = destination
        appStart.startDetection()

        appStart.track(initialLifecycle: AppStartLifecycleSnapshot(
            launchOrigin: .background,
            didFinishLaunching: didFinishLaunching,
            willEnterForeground: willEnterForeground,
            didBecomeActive: nil
        ))

        try checkNotDeterminedType(in: destination)

        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)

        try checkDeterminedType(.warm, in: destination)
        XCTAssertEqual(destination.storedAppStart?.start, willEnterForeground)
    }

    func testAutomaticActivationAfterManualBackgroundTrackDoesNotSendDuplicate() throws {
        let destination = DebugDestination()
        let didBecomeActive = Date()
        let didFinishLaunching = didBecomeActive.addingTimeInterval(-5.0)
        let willEnterForeground = didBecomeActive.addingTimeInterval(-1.0)

        let appStart = AppStart()
        appStart.processStartTimestamp = didBecomeActive.addingTimeInterval(-6.0)
        appStart.destination = destination

        appStart.track(
            didBecomeActive: didBecomeActive,
            didFinishLaunching: didFinishLaunching,
            willEnterForeground: willEnterForeground,
            launchOrigin: .background
        )
        appStart.withStateAccess {
            appStart.didBecomeActiveTimestamp = didBecomeActive.addingTimeInterval(1.0)
            appStart.determineAndSendWithStateAccess()
        }

        try checkDeterminedType(.warm, in: destination)
        XCTAssertEqual(destination.storedAppStart?.start, willEnterForeground)
        XCTAssertEqual(destination.storedAppStart?.end, didBecomeActive)
    }

    func testManualTrackWithUnknownOriginAndLongBackgroundResidenceIsWarm() throws {
        let destination = DebugDestination()
        let didBecomeActive = Date()
        let didFinishLaunching = didBecomeActive.addingTimeInterval(-12.0 * 60.0 * 60.0)
        let willEnterForeground = didBecomeActive.addingTimeInterval(-1.0)

        let appStart = AppStart()
        appStart.processStartTimestamp = didFinishLaunching.addingTimeInterval(-1.0)
        appStart.destination = destination

        appStart.track(
            didBecomeActive: didBecomeActive,
            didFinishLaunching: didFinishLaunching,
            willEnterForeground: willEnterForeground,
            launchOrigin: .unknown
        )

        try checkDeterminedType(.warm, in: destination)
        XCTAssertEqual(destination.storedAppStart?.start, willEnterForeground)
        XCTAssertEqual(destination.storedAppStart?.end, didBecomeActive)
    }
}
