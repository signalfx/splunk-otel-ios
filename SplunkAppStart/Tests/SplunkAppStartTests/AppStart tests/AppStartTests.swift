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

@_spi(SplunkInternal) @testable import SplunkAppStart

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
        XCTAssertEqual(appStart.initialAppStartState, .emitted)
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

        try checkNotDeterminedType(in: destination)
        XCTAssertEqual(appStart.initialAppStartState, .suppressed(.unknownLaunchOrigin))
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

        try checkNotDeterminedType(in: destination)
        XCTAssertEqual(appStart.initialAppStartState, .suppressed(.unknownLaunchOrigin))
    }

    func testManualTrackUsesSuppliedActivationTimestampAsEnd() {
        let destination = DebugDestination()
        let now = Date()
        let didBecomeActive = now.addingTimeInterval(-1.0)

        let appStart = AppStart()
        appStart.processStartTimestamp = now.addingTimeInterval(-2.0)
        appStart.destination = destination

        appStart.track(
            didBecomeActive: didBecomeActive,
            didFinishLaunching: now.addingTimeInterval(-1.9),
            willEnterForeground: now.addingTimeInterval(-1.8)
        )

        XCTAssertEqual(destination.storedAppStart?.end, didBecomeActive)
    }

    func testManualTrackFromBackgroundThreadIsHandledOnMain() throws {
        let destination = DebugDestination()
        let now = Date()
        let appStart = AppStart()
        appStart.processStartTimestamp = now.addingTimeInterval(-2.0)
        appStart.destination = destination

        let handoffCompleted = expectation(description: "background handoff completed")
        DispatchQueue.global().async {
            appStart.track(
                didBecomeActive: now,
                didFinishLaunching: now.addingTimeInterval(-1.0),
                willEnterForeground: now.addingTimeInterval(-0.5)
            )
            DispatchQueue.main.async {
                handoffCompleted.fulfill()
            }
        }

        wait(for: [handoffCompleted], timeout: 1.0)
        try checkDeterminedType(.cold, in: destination)
    }

    func testPartialLifecycleSnapshotCompletesFromNativeNotification() throws {
        let destination = DebugDestination()
        let now = Date()
        let didFinishLaunching = now.addingTimeInterval(-2.0)
        let willEnterForeground = now.addingTimeInterval(-1.0)

        let appStart = AppStart()
        appStart.destination = destination
        appStart.startDetection()
        defer { appStart.stopDetection() }
        appStart.processStartTimestamp = now.addingTimeInterval(-3.0)

        appStart.track(
            initialLifecycle: AppStartLifecycleSnapshot(
                launchOrigin: .foreground,
                didFinishLaunching: didFinishLaunching,
                willEnterForeground: willEnterForeground,
                didBecomeActive: nil
            )
        )

        let beforeNotification = Date()
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        drainMainQueue()
        let afterNotification = Date()

        try checkDeterminedType(.cold, in: destination)
        let end = try XCTUnwrap(destination.storedAppStart?.end)
        XCTAssertGreaterThanOrEqual(end, beforeNotification)
        XCTAssertLessThanOrEqual(end, afterNotification)

        let events = try XCTUnwrap(destination.storedAppStart?.events)
        XCTAssertEqual(events.first { $0.name == UIApplication.didFinishLaunchingNotification.rawValue }?.timestamp, didFinishLaunching)
        XCTAssertEqual(events.first { $0.name == UIApplication.willEnterForegroundNotification.rawValue }?.timestamp, willEnterForeground)
    }

    func testNativeNotificationBeforeSnapshotUsesSnapshotOrigin() throws {
        let destination = DebugDestination()
        let now = Date()

        let appStart = AppStart()
        appStart.destination = destination
        appStart.startDetection()
        defer { appStart.stopDetection() }
        appStart.processStartTimestamp = now.addingTimeInterval(-3.0)

        // The native callback queues initial determination. The snapshot must be able to
        // provide launch provenance before that queued work runs.
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        appStart.track(
            initialLifecycle: AppStartLifecycleSnapshot(
                launchOrigin: .background,
                didFinishLaunching: now.addingTimeInterval(-2.0),
                willEnterForeground: now.addingTimeInterval(-1.0),
                didBecomeActive: nil
            )
        )
        drainMainQueue()

        try checkDeterminedType(.warm, in: destination)
    }

    func testSubsequentActivationDoesNotUseInitialLaunchTimestamp() throws {
        let destination = DebugDestination()
        let now = Date()
        let appStart = AppStart()
        appStart.destination = destination
        appStart.startDetection()
        defer { appStart.stopDetection() }
        appStart.processStartTimestamp = now.addingTimeInterval(-4.0)

        appStart.track(
            initialLifecycle: AppStartLifecycleSnapshot(
                launchOrigin: .foreground,
                didFinishLaunching: now.addingTimeInterval(-3.0),
                willEnterForeground: now.addingTimeInterval(-2.0),
                didBecomeActive: now.addingTimeInterval(-1.0)
            )
        )

        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)

        XCTAssertNil(appStart.backgroundLaunchDetected)

        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        drainMainQueue()

        try checkDeterminedType(.hot, in: destination)
    }

    func testForegroundSnapshotDoesNotOverridePrewarm() throws {
        let destination = DebugDestination()
        let now = Date()
        let willEnterForeground = now.addingTimeInterval(-1.0)

        let appStart = AppStart()
        appStart.processStartTimestamp = now.addingTimeInterval(-120.0)
        appStart.prewarmDetected = true
        appStart.destination = destination

        appStart.track(
            initialLifecycle: AppStartLifecycleSnapshot(
                launchOrigin: .foreground,
                didFinishLaunching: now.addingTimeInterval(-119.0),
                willEnterForeground: willEnterForeground,
                didBecomeActive: now
            )
        )

        try checkDeterminedType(.warm, in: destination)
        XCTAssertEqual(destination.storedAppStart?.start, willEnterForeground)
    }

    func testForegroundSnapshotWithoutProcessStartIsSuppressed() throws {
        let destination = DebugDestination()
        let now = Date()

        let appStart = AppStart()
        appStart.destination = destination

        appStart.track(
            initialLifecycle: AppStartLifecycleSnapshot(
                launchOrigin: .foreground,
                didFinishLaunching: now.addingTimeInterval(-2.0),
                willEnterForeground: now.addingTimeInterval(-1.0),
                didBecomeActive: now
            )
        )

        try checkNotDeterminedType(in: destination)
    }

    func testForegroundSnapshotWithInvalidProcessOrderIsSuppressed() throws {
        let destination = DebugDestination()
        let now = Date()

        let appStart = AppStart()
        appStart.processStartTimestamp = now.addingTimeInterval(-1.0)
        appStart.destination = destination

        appStart.track(
            initialLifecycle: AppStartLifecycleSnapshot(
                launchOrigin: .foreground,
                didFinishLaunching: now.addingTimeInterval(-2.0),
                willEnterForeground: now.addingTimeInterval(-0.5),
                didBecomeActive: now
            )
        )

        try checkNotDeterminedType(in: destination)
    }

    func testLifecycleSnapshotBackgroundLaunchUsesForegroundBoundary() throws {
        let destination = DebugDestination()
        let now = Date()
        let didFinishLaunching = now.addingTimeInterval(-120)
        let willEnterForeground = now.addingTimeInterval(-1)
        let didBecomeActive = now

        let appStart = AppStart()
        appStart.processStartTimestamp = now.addingTimeInterval(-121)
        appStart.destination = destination

        appStart.track(
            initialLifecycle: AppStartLifecycleSnapshot(
                launchOrigin: .background,
                didFinishLaunching: didFinishLaunching,
                willEnterForeground: willEnterForeground,
                didBecomeActive: didBecomeActive
            )
        )

        try checkDeterminedType(.warm, in: destination)
        XCTAssertEqual(destination.storedAppStart?.start, willEnterForeground)
        XCTAssertEqual(destination.storedAppStart?.end, didBecomeActive)
    }

    func testLifecycleSnapshotBackgroundLaunchWithoutForegroundIsSuppressed() throws {
        let destination = DebugDestination()
        let now = Date()

        let appStart = AppStart()
        appStart.processStartTimestamp = now.addingTimeInterval(-120)
        appStart.destination = destination

        appStart.track(
            initialLifecycle: AppStartLifecycleSnapshot(
                launchOrigin: .background,
                didFinishLaunching: now.addingTimeInterval(-120),
                willEnterForeground: nil,
                didBecomeActive: now
            )
        )

        try checkNotDeterminedType(in: destination)
    }

    func testSuppressedInitialSnapshotIsNotRetriedByAnotherSnapshot() throws {
        let destination = DebugDestination()
        let now = Date()

        let appStart = AppStart()
        appStart.processStartTimestamp = now.addingTimeInterval(-120)
        appStart.destination = destination

        appStart.track(
            initialLifecycle: AppStartLifecycleSnapshot(
                launchOrigin: .background,
                didFinishLaunching: now.addingTimeInterval(-120),
                willEnterForeground: nil,
                didBecomeActive: now
            )
        )

        appStart.track(
            initialLifecycle: AppStartLifecycleSnapshot(
                launchOrigin: .foreground,
                didFinishLaunching: now.addingTimeInterval(-120),
                willEnterForeground: now.addingTimeInterval(-1),
                didBecomeActive: now
            )
        )

        try checkNotDeterminedType(in: destination)
    }

    func testSuppressedInitialSnapshotIsNotRetriedByLegacyTrack() throws {
        let destination = DebugDestination()
        let now = Date()

        let appStart = AppStart()
        appStart.processStartTimestamp = now.addingTimeInterval(-120.0)
        appStart.destination = destination

        appStart.track(
            initialLifecycle: AppStartLifecycleSnapshot(
                launchOrigin: .background,
                didFinishLaunching: now.addingTimeInterval(-120.0),
                willEnterForeground: nil,
                didBecomeActive: now
            )
        )

        appStart.track(
            didBecomeActive: now,
            didFinishLaunching: now.addingTimeInterval(-120.0),
            willEnterForeground: now.addingTimeInterval(-1.0)
        )

        try checkNotDeterminedType(in: destination)
    }

    func testForegroundSnapshotOverMaximumDurationIsSuppressed() throws {
        let destination = DebugDestination()
        let now = Date()
        let processStart = now.addingTimeInterval(-30)
        let didBecomeActive = now.addingTimeInterval(-1)

        let appStart = AppStart()
        appStart.processStartTimestamp = processStart
        appStart.destination = destination

        appStart.track(
            initialLifecycle: AppStartLifecycleSnapshot(
                launchOrigin: .foreground,
                didFinishLaunching: now.addingTimeInterval(-29),
                willEnterForeground: now.addingTimeInterval(-2),
                didBecomeActive: didBecomeActive
            )
        )

        try checkNotDeterminedType(in: destination)
        XCTAssertEqual(appStart.initialAppStartState, .suppressed(.maxDurationExceeded))
    }

    func testInvalidTimestampOrderIsSuppressed() throws {
        let destination = DebugDestination()
        let now = Date()

        let appStart = AppStart()
        appStart.processStartTimestamp = now.addingTimeInterval(1.0)
        appStart.destination = destination

        appStart.track(
            initialLifecycle: AppStartLifecycleSnapshot(
                launchOrigin: .foreground,
                didFinishLaunching: now.addingTimeInterval(-1.0),
                willEnterForeground: now.addingTimeInterval(-0.5),
                didBecomeActive: now
            )
        )

        try checkNotDeterminedType(in: destination)
        XCTAssertEqual(appStart.initialAppStartState, .suppressed(.invalidTimestampOrder))
    }

    func testUnknownSnapshotWithoutForegroundBoundaryIsSuppressed() throws {
        let destination = DebugDestination()
        let now = Date()

        let appStart = AppStart()
        appStart.processStartTimestamp = now.addingTimeInterval(-2.0)
        appStart.destination = destination

        appStart.track(
            initialLifecycle: AppStartLifecycleSnapshot(
                launchOrigin: .unknown,
                didFinishLaunching: now.addingTimeInterval(-2.0),
                willEnterForeground: nil,
                didBecomeActive: now
            )
        )

        try checkNotDeterminedType(in: destination)
        XCTAssertEqual(appStart.initialAppStartState, .suppressed(.unknownLaunchOrigin))
    }

    func testPartialSnapshotTimeoutIsSuppressedAndCannotBeRetried() throws {
        let destination = DebugDestination()
        let now = Date()

        let appStart = AppStart()
        appStart.processStartTimestamp = now.addingTimeInterval(-2.0)
        appStart.destination = destination
        appStart.initialHandoffTimeout = 0.01

        appStart.track(
            initialLifecycle: AppStartLifecycleSnapshot(
                launchOrigin: .unknown,
                didFinishLaunching: now.addingTimeInterval(-2.0),
                willEnterForeground: now.addingTimeInterval(-1.0),
                didBecomeActive: nil
            )
        )

        let timeoutCompleted = expectation(description: "initial handoff timeout completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            timeoutCompleted.fulfill()
        }
        wait(for: [timeoutCompleted], timeout: 1.0)

        XCTAssertEqual(appStart.initialAppStartState, .suppressed(.missingDidBecomeActive))
        try checkNotDeterminedType(in: destination)

        appStart.track(
            initialLifecycle: AppStartLifecycleSnapshot(
                launchOrigin: .foreground,
                didFinishLaunching: now.addingTimeInterval(-1.0),
                willEnterForeground: now.addingTimeInterval(-0.5),
                didBecomeActive: now
            )
        )

        XCTAssertEqual(appStart.initialAppStartState, .suppressed(.missingDidBecomeActive))
        try checkNotDeterminedType(in: destination)
    }

    func testTrustedHybridOriginCanCompleteUnknownCoreSnapshot() throws {
        let destination = DebugDestination()
        let now = Date()

        let appStart = AppStart()
        appStart.processStartTimestamp = now.addingTimeInterval(-2.0)
        appStart.destination = destination

        appStart.consume(
            coreLifecycle: nil,
            snapshot: AppStartLifecycleSnapshot(
                launchOrigin: .unknown,
                didFinishLaunching: now.addingTimeInterval(-1.5),
                willEnterForeground: nil,
                didBecomeActive: nil
            )
        )

        appStart.track(
            initialLifecycle: AppStartLifecycleSnapshot(
                launchOrigin: .foreground,
                didFinishLaunching: nil,
                willEnterForeground: nil,
                didBecomeActive: now
            )
        )

        try checkDeterminedType(.cold, in: destination)
        XCTAssertEqual(appStart.initialAppStartState, .emitted)
    }

    func testUnknownSnapshotWithLongBackgroundGapIsSuppressed() throws {
        let destination = DebugDestination()
        let now = Date()

        let appStart = AppStart()
        appStart.processStartTimestamp = now.addingTimeInterval(-20)
        appStart.destination = destination

        appStart.track(
            initialLifecycle: AppStartLifecycleSnapshot(
                launchOrigin: .unknown,
                didFinishLaunching: now.addingTimeInterval(-20),
                willEnterForeground: now.addingTimeInterval(-5),
                didBecomeActive: now
            )
        )

        try checkNotDeterminedType(in: destination)
        XCTAssertEqual(appStart.initialAppStartState, .suppressed(.unknownLaunchOrigin))
    }

    func testUnknownSnapshotWithinThresholdIsSuppressed() throws {
        let destination = DebugDestination()
        let now = Date()
        let processStart = now.addingTimeInterval(-5.0)

        let appStart = AppStart()
        appStart.processStartTimestamp = processStart
        appStart.destination = destination

        appStart.track(
            initialLifecycle: AppStartLifecycleSnapshot(
                launchOrigin: .unknown,
                didFinishLaunching: now.addingTimeInterval(-4.0),
                willEnterForeground: now.addingTimeInterval(-3.0),
                didBecomeActive: now
            )
        )

        try checkNotDeterminedType(in: destination)
        XCTAssertEqual(appStart.initialAppStartState, .suppressed(.unknownLaunchOrigin))
    }

    func testCoreLifecycleEventsContinueAfterInitialEmission() throws {
        let destination = DebugDestination()
        let now = Date()

        let appStart = AppStart()
        appStart.processStartTimestamp = now.addingTimeInterval(-2.0)
        appStart.destination = destination

        appStart.consume(
            coreLifecycle: nil,
            snapshot: AppStartLifecycleSnapshot(
                launchOrigin: .foreground,
                didFinishLaunching: now.addingTimeInterval(-1.5),
                willEnterForeground: nil,
                didBecomeActive: now.addingTimeInterval(-1.0)
            )
        )

        XCTAssertEqual(appStart.initialAppStartState, .emitted)

        appStart.consume(
            coreLifecycle: .willResignActive(now.addingTimeInterval(-0.5)),
            snapshot: AppStartLifecycleSnapshot(
                launchOrigin: .foreground,
                didFinishLaunching: nil,
                willEnterForeground: nil,
                didBecomeActive: nil
            )
        )
        appStart.consume(
            coreLifecycle: .willEnterForeground(now.addingTimeInterval(-0.25)),
            snapshot: AppStartLifecycleSnapshot(
                launchOrigin: .foreground,
                didFinishLaunching: nil,
                willEnterForeground: nil,
                didBecomeActive: nil
            )
        )
        appStart.consume(
            coreLifecycle: .didBecomeActive(now),
            snapshot: AppStartLifecycleSnapshot(
                launchOrigin: .foreground,
                didFinishLaunching: nil,
                willEnterForeground: nil,
                didBecomeActive: nil
            )
        )

        try checkDeterminedType(.hot, in: destination)
        XCTAssertEqual(destination.storedAppStart?.start, now.addingTimeInterval(-0.25))
        XCTAssertEqual(destination.storedAppStart?.end, now)
    }
}
