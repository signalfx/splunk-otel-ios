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
