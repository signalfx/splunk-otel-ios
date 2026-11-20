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

extension AppStartReducerTests {

    // MARK: - Hybrid event ordering

    func testBackgroundActivationWaitsForLateHybridBoundary() {
        let start = Date(timeIntervalSinceReferenceDate: 1_884)
        let launch = start.addingTimeInterval(0.1)
        let foreground = start.addingTimeInterval(1)
        let active = foreground.addingTimeInterval(0.4)
        var state = AppStartReducer.State.initial(
            AppStartReducer.Evidence(
                processStart: start,
                launchOrigin: .unknown,
                didFinishLaunching: nil,
                foregroundBoundary: nil,
                didBecomeActive: nil
            )
        )

        state =
            AppStartReducer.reduce(
                state: state,
                event: .didFinishLaunching(launch, .background)
            )
            .state
        let activation = AppStartReducer.reduce(
            state: state,
            event: .didBecomeActive(active)
        )

        XCTAssertNil(activation.action)

        let handoff = AppStartReducer.reduce(
            state: activation.state,
            event: .hybridSnapshot(
                AppStartLifecycleSnapshot(
                    launchOrigin: .background,
                    didFinishLaunching: launch,
                    willEnterForeground: foreground,
                    didBecomeActive: active
                ),
                receivedAt: active.addingTimeInterval(0.1)
            )
        )

        guard case let .send(span) = handoff.action else {
            XCTFail("Expected the late hybrid boundary to recover the warm start.")
            return
        }

        XCTAssertEqual(handoff.state, .active(.emitted))
        XCTAssertEqual(span.type, .warm)
        XCTAssertEqual(span.start, foreground)
        XCTAssertEqual(span.end, active)
    }

    func testForegroundLaunchSuppressesAtTerminationAfterResigningActive() {
        let start = Date(timeIntervalSinceReferenceDate: 1_883)
        let initial = AppStartReducer.State.initial(
            AppStartReducer.Evidence(
                processStart: start,
                launchOrigin: .foreground,
                didFinishLaunching: start.addingTimeInterval(0.1),
                foregroundBoundary: nil,
                didBecomeActive: nil
            )
        )

        let resigning = AppStartReducer.reduce(
            state: initial,
            event: .willResignActive
        )

        XCTAssertEqual(resigning.state, initial)
        XCTAssertNil(resigning.action)

        let termination = AppStartReducer.reduce(
            state: resigning.state,
            event: .willTerminate
        )

        XCTAssertEqual(
            termination.state,
            .stopped(.suppressed(.missingDidBecomeActive))
        )
        guard case .suppress(.missingDidBecomeActive) = termination.action else {
            XCTFail("Expected the interrupted cold start to fail closed.")
            return
        }
    }

    func testHybridSnapshotAfterInitialResolutionIsIgnored() {
        let timestamp = Date(timeIntervalSinceReferenceDate: 1_889)
        let snapshot = AppStartLifecycleSnapshot(
            launchOrigin: .background,
            didFinishLaunching: timestamp,
            willEnterForeground: timestamp.addingTimeInterval(0.1),
            didBecomeActive: timestamp.addingTimeInterval(0.2)
        )

        for state in [
            AppStartReducer.State.active(.emitted),
            .background(.emitted)
        ] {
            let result = AppStartReducer.reduce(
                state: state,
                event: .hybridSnapshot(
                    snapshot,
                    receivedAt: timestamp.addingTimeInterval(0.3)
                )
            )

            XCTAssertEqual(result.state, state)
            XCTAssertNil(result.action)
        }
    }
}
