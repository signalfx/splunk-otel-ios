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
    func testSuppressedInitialSnapshotStillAllowsLaterHotStarts() throws {
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

        appStart.consume(
            coreLifecycle: .willResignActive(now.addingTimeInterval(0.1)),
            snapshot: AppStartLifecycleSnapshot(
                launchOrigin: .unknown,
                didFinishLaunching: nil,
                willEnterForeground: nil,
                didBecomeActive: nil
            )
        )
        appStart.consume(
            coreLifecycle: .willEnterForeground(now.addingTimeInterval(0.2)),
            snapshot: AppStartLifecycleSnapshot(
                launchOrigin: .unknown,
                didFinishLaunching: nil,
                willEnterForeground: nil,
                didBecomeActive: nil
            )
        )
        appStart.consume(
            coreLifecycle: .didBecomeActive(now.addingTimeInterval(0.3)),
            snapshot: AppStartLifecycleSnapshot(
                launchOrigin: .unknown,
                didFinishLaunching: nil,
                willEnterForeground: nil,
                didBecomeActive: nil
            )
        )

        try checkDeterminedType(.hot, in: destination)
    }

    func testCoreSnapshotDoesNotStartHybridTimeout() throws {
        let destination = DebugDestination()
        let now = Date()

        let appStart = AppStart()
        appStart.destination = destination
        appStart.initialHandoffTimeout = 0.01

        appStart.consume(
            coreLifecycle: nil,
            snapshot: AppStartLifecycleSnapshot(
                launchOrigin: .foreground,
                launchOriginConfidence: .observed,
                didFinishLaunching: now.addingTimeInterval(-1.0),
                willEnterForeground: now.addingTimeInterval(-0.5),
                didBecomeActive: nil
            )
        )

        let timeoutCompleted = expectation(description: "native lifecycle wait completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            timeoutCompleted.fulfill()
        }
        wait(for: [timeoutCompleted], timeout: 1.0)

        XCTAssertEqual(appStart.initialAppStartState, .pending)
        try checkNotDeterminedType(in: destination)
    }

    func testInferredCoreBackgroundSnapshotWaitsForObservedHybridHandoff() throws {
        let destination = DebugDestination()
        let now = Date()

        let appStart = AppStart()
        appStart.processStartTimestamp = now.addingTimeInterval(-120.0)
        appStart.destination = destination
        appStart.initialHandoffTimeout = 0.1

        appStart.consume(
            coreLifecycle: nil,
            snapshot: AppStartLifecycleSnapshot(
                launchOrigin: .background,
                launchOriginConfidence: .inferred,
                didFinishLaunching: now.addingTimeInterval(-120.0),
                willEnterForeground: now.addingTimeInterval(-1.0),
                didBecomeActive: now
            )
        )

        XCTAssertEqual(appStart.initialAppStartState, .pending)
        try checkNotDeterminedType(in: destination)

        appStart.track(
            initialLifecycle: AppStartLifecycleSnapshot(
                launchOrigin: .background,
                launchOriginConfidence: .observed,
                didFinishLaunching: nil,
                willEnterForeground: now.addingTimeInterval(-1.0),
                didBecomeActive: now
            )
        )

        try checkDeterminedType(.warm, in: destination)
    }

    func testLifecycleResolutionWaitsForInitializationData() throws {
        let destination = DebugDestination()
        let now = Date()

        let appStart = AppStart()
        appStart.processStartTimestamp = now.addingTimeInterval(-2.0)
        appStart.destination = destination
        appStart.deferInitialLifecycleResolution()

        appStart.consume(
            coreLifecycle: nil,
            snapshot: AppStartLifecycleSnapshot(
                launchOrigin: .foreground,
                launchOriginConfidence: .observed,
                didFinishLaunching: now.addingTimeInterval(-1.5),
                willEnterForeground: now.addingTimeInterval(-1.0),
                didBecomeActive: now
            )
        )

        try checkNotDeterminedType(in: destination)
        XCTAssertEqual(appStart.initialAppStartState, .pending)

        appStart.reportAgentInitialize(
            start: now.addingTimeInterval(-1.5),
            end: now.addingTimeInterval(-0.1),
            events: ["modules_connected": now.addingTimeInterval(-0.5)],
            configurationSettings: [:]
        )
        appStart.resumeInitialLifecycleResolution()

        try checkDeterminedType(.cold, in: destination)
        XCTAssertNotNil(destination.storedInitialize)
    }

    func testObservedOriginOverridesConflictingInferredOrigin() throws {
        let destination = DebugDestination()
        let now = Date()

        let appStart = AppStart()
        appStart.processStartTimestamp = now.addingTimeInterval(-2.0)
        appStart.destination = destination

        appStart.consume(
            coreLifecycle: nil,
            snapshot: AppStartLifecycleSnapshot(
                launchOrigin: .background,
                launchOriginConfidence: .inferred,
                didFinishLaunching: now.addingTimeInterval(-1.5),
                willEnterForeground: nil,
                didBecomeActive: nil
            )
        )

        appStart.track(
            initialLifecycle: AppStartLifecycleSnapshot(
                launchOrigin: .foreground,
                launchOriginConfidence: .observed,
                didFinishLaunching: now.addingTimeInterval(-1.5),
                willEnterForeground: now.addingTimeInterval(-1.0),
                didBecomeActive: now
            )
        )

        try checkDeterminedType(.cold, in: destination)
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
        appStart.prewarmDetected = true
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
