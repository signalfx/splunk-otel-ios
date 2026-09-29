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
                launchOriginConfidence: .observed,
                didFinishLaunching: didFinishLaunching,
                willEnterForeground: willEnterForeground,
                didBecomeActive: didBecomeActive
            )
        )

        try checkDeterminedType(.warm, in: destination)
        XCTAssertEqual(destination.storedAppStart?.start, willEnterForeground)
        XCTAssertEqual(destination.storedAppStart?.end, didBecomeActive)
    }

    func testLifecycleSnapshotBackgroundLaunchWithoutForegroundRemainsPending() throws {
        let destination = DebugDestination()
        let now = Date()

        let appStart = AppStart()
        appStart.processStartTimestamp = now.addingTimeInterval(-120)
        appStart.initialHandoffTimeout = 0.01
        appStart.destination = destination

        appStart.track(
            initialLifecycle: AppStartLifecycleSnapshot(
                launchOrigin: .background,
                launchOriginConfidence: .observed,
                didFinishLaunching: now.addingTimeInterval(-120),
                willEnterForeground: nil,
                didBecomeActive: now
            )
        )

        drainMainQueue()

        let timeoutCompleted = expectation(description: "background launch remains pending")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            timeoutCompleted.fulfill()
        }
        wait(for: [timeoutCompleted], timeout: 1.0)

        XCTAssertEqual(appStart.initialAppStartState, .pending)
        try checkNotDeterminedType(in: destination)

        appStart.track(
            initialLifecycle: AppStartLifecycleSnapshot(
                launchOrigin: .background,
                launchOriginConfidence: .observed,
                didFinishLaunching: now.addingTimeInterval(-120),
                willEnterForeground: now.addingTimeInterval(-1),
                didBecomeActive: now
            )
        )

        try checkDeterminedType(.warm, in: destination)
    }

    func testBackgroundLaunchWithoutForegroundIsSuppressedOnTermination() throws {
        let destination = DebugDestination()
        let now = Date()

        let appStart = AppStart()
        appStart.processStartTimestamp = now.addingTimeInterval(-120)
        appStart.destination = destination

        appStart.track(
            initialLifecycle: AppStartLifecycleSnapshot(
                launchOrigin: .background,
                launchOriginConfidence: .observed,
                didFinishLaunching: now.addingTimeInterval(-120),
                willEnterForeground: nil,
                didBecomeActive: now
            )
        )

        // `track(initialLifecycle:)` may marshal to the main queue when the test
        // runner invokes it off-main. Drain it before injecting termination.
        drainMainQueue()

        appStart.processCoreLifecycleEvent(.willTerminate(now.addingTimeInterval(0.1)))

        try checkNotDeterminedType(in: destination)
        XCTAssertEqual(appStart.initialAppStartState, .suppressed(.backgroundWithoutForeground))
    }

    func testRecordedBackgroundTerminationSuppressesPendingSnapshot() throws {
        let destination = DebugDestination()
        let notificationCenter = NotificationCenter()
        let recorder = AppLifecycleRecorder(notificationCenter: notificationCenter)

        notificationCenter.post(name: UIApplication.didFinishLaunchingNotification, object: nil)
        notificationCenter.post(name: UIApplication.willTerminateNotification, object: nil)

        let snapshot = recorder.snapshot()
        let appStart = AppStart()
        appStart.destination = destination
        appStart.processStartTimestamp = Date(timeIntervalSinceNow: -2)

        appStart.consume(
            coreLifecycle: nil,
            snapshot: AppStartLifecycleSnapshot(
                launchOrigin: .background,
                launchOriginConfidence: .observed,
                didFinishLaunching: snapshot.didFinishLaunching,
                willEnterForeground: nil,
                didBecomeActive: nil,
                events: snapshot.events
            )
        )

        XCTAssertEqual(appStart.initialAppStartState, .suppressed(.backgroundWithoutForeground))
        try checkNotDeterminedType(in: destination)
    }

    func testBackgroundPendingSnapshotCanBeCompletedByLegacyTrack() throws {
        let destination = DebugDestination()
        let now = Date()

        let appStart = AppStart()
        appStart.processStartTimestamp = now.addingTimeInterval(-120.0)
        appStart.destination = destination

        appStart.track(
            initialLifecycle: AppStartLifecycleSnapshot(
                launchOrigin: .background,
                launchOriginConfidence: .observed,
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

        try checkDeterminedType(.warm, in: destination)
    }

    func testTrustedForegroundSnapshotOverFormerMaximumDurationIsEmitted() throws {
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
                launchOriginConfidence: .observed,
                didFinishLaunching: now.addingTimeInterval(-29),
                willEnterForeground: now.addingTimeInterval(-2),
                didBecomeActive: didBecomeActive
            )
        )

        try checkDeterminedType(.cold, in: destination)
        XCTAssertEqual(appStart.initialAppStartState, .emitted)
    }

    func testInferredOriginDoesNotBypassMaximumDurationGuard() throws {
        let destination = DebugDestination()
        let now = Date()

        let appStart = AppStart()
        appStart.processStartTimestamp = now.addingTimeInterval(-30)
        appStart.maxAppStartDuration = 5
        appStart.destination = destination

        appStart.track(
            initialLifecycle: AppStartLifecycleSnapshot(
                launchOrigin: .foreground,
                launchOriginConfidence: .inferred,
                didFinishLaunching: now.addingTimeInterval(-29),
                willEnterForeground: now.addingTimeInterval(-2),
                didBecomeActive: now
            )
        )

        try checkNotDeterminedType(in: destination)
        XCTAssertEqual(appStart.initialAppStartState, .suppressed(.maxDurationExceeded))
    }

    func testInferredBackgroundOriginDoesNotEmitWarmStart() throws {
        let destination = DebugDestination()
        let now = Date()

        let appStart = AppStart()
        appStart.processStartTimestamp = now.addingTimeInterval(-120)
        appStart.destination = destination

        appStart.track(
            initialLifecycle: AppStartLifecycleSnapshot(
                launchOrigin: .background,
                launchOriginConfidence: .inferred,
                didFinishLaunching: now.addingTimeInterval(-120),
                willEnterForeground: now.addingTimeInterval(-1),
                didBecomeActive: now
            )
        )

        try checkNotDeterminedType(in: destination)
        XCTAssertEqual(appStart.initialAppStartState, .suppressed(.unknownLaunchOrigin))
    }

    func testObservedHybridOriginUpgradesInferredCoreOrigin() throws {
        let destination = DebugDestination()
        let now = Date()

        let appStart = AppStart()
        appStart.processStartTimestamp = now.addingTimeInterval(-120)
        appStart.destination = destination

        appStart.consume(
            coreLifecycle: nil,
            snapshot: AppStartLifecycleSnapshot(
                launchOrigin: .background,
                launchOriginConfidence: .inferred,
                didFinishLaunching: now.addingTimeInterval(-120),
                willEnterForeground: now.addingTimeInterval(-1),
                didBecomeActive: nil
            )
        )

        appStart.track(
            initialLifecycle: AppStartLifecycleSnapshot(
                launchOrigin: .background,
                launchOriginConfidence: .observed,
                didFinishLaunching: nil,
                willEnterForeground: now.addingTimeInterval(-1),
                didBecomeActive: now
            )
        )

        try checkDeterminedType(.warm, in: destination)
        XCTAssertEqual(appStart.initialAppStartState, .emitted)
    }

    func testUntrustedLegacyStartOverConfiguredGuardIsSuppressed() throws {
        let destination = DebugDestination()
        let now = Date()

        let appStart = AppStart()
        appStart.processStartTimestamp = now.addingTimeInterval(-30)
        appStart.maxAppStartDuration = 5
        appStart.destination = destination

        appStart.track(
            didBecomeActive: now,
            didFinishLaunching: now.addingTimeInterval(-5),
            willEnterForeground: now.addingTimeInterval(-1)
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
}
