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

import XCTest

@_spi(SplunkInternal) @testable import SplunkAppStart
@_spi(SplunkInternal) @testable import SplunkCommon

extension AppStartTests {
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
        DispatchQueue.global()
            .async {
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
                launchOriginConfidence: .observed,
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
}
