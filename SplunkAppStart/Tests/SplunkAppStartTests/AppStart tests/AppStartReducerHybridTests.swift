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

    // MARK: - Hybrid evidence

    func testNativeForegroundBoundaryWinsOverStaleHybridBoundary() {
        let start = Date(timeIntervalSinceReferenceDate: 1_850)
        let staleForeground = start.addingTimeInterval(1)
        let nativeForeground = start.addingTimeInterval(3 * 60 * 60)
        let active = nativeForeground.addingTimeInterval(0.4)
        var state = hybridInitialState(processStart: start)

        for event in [
            AppStartReducer.Event.didFinishLaunching(
                start.addingTimeInterval(0.1),
                .background
            ),
            .willEnterForeground(nativeForeground),
            .hybridSnapshot(
                AppStartLifecycleSnapshot(
                    launchOrigin: .background,
                    didFinishLaunching: start.addingTimeInterval(0.1),
                    willEnterForeground: staleForeground,
                    didBecomeActive: active
                ),
                receivedAt: nativeForeground.addingTimeInterval(1)
            )
        ] {
            let result = AppStartReducer.reduce(state: state, event: event)
            state = result.state

            if case let .send(span) = result.action {
                XCTAssertEqual(span.type, .warm)
                XCTAssertEqual(span.start, nativeForeground)
                XCTAssertEqual(span.end, active)
            }
        }

        XCTAssertEqual(state, .active(.emitted))
    }

    func testRepeatedHybridHandoffCannotReplaceEarlierEvidence() {
        let start = Date(timeIntervalSinceReferenceDate: 1_880)
        let laterForeground = start.addingTimeInterval(3 * 60 * 60)
        var state = hybridInitialState(processStart: start)

        let incomplete = AppStartLifecycleSnapshot(
            launchOrigin: .background,
            didFinishLaunching: start.addingTimeInterval(0.1),
            willEnterForeground: nil,
            didBecomeActive: nil
        )
        state =
            AppStartReducer.reduce(
                state: state,
                event: .hybridSnapshot(
                    incomplete,
                    receivedAt: start.addingTimeInterval(1)
                )
            )
            .state

        let repeated = AppStartLifecycleSnapshot(
            launchOrigin: .background,
            didFinishLaunching: start.addingTimeInterval(0.1),
            willEnterForeground: laterForeground,
            didBecomeActive: laterForeground.addingTimeInterval(0.4)
        )
        let result = AppStartReducer.reduce(
            state: state,
            event: .hybridSnapshot(
                repeated,
                receivedAt: laterForeground.addingTimeInterval(1)
            )
        )

        XCTAssertEqual(
            result.state,
            .active(.suppressed(.conflictingLifecycleEvidence))
        )
        guard case .suppress(.conflictingLifecycleEvidence) = result.action else {
            XCTFail("Expected a repeated hybrid handoff to be suppressed.")
            return
        }
    }

    func testIncompleteHybridBoundaryCannotPairWithLaterActivation() {
        let start = Date(timeIntervalSinceReferenceDate: 1_890)
        let foreground = start.addingTimeInterval(1)
        let handoff = AppStartReducer.reduce(
            state: hybridInitialState(processStart: start),
            event: .hybridSnapshot(
                AppStartLifecycleSnapshot(
                    launchOrigin: .background,
                    didFinishLaunching: start.addingTimeInterval(0.1),
                    willEnterForeground: foreground,
                    didBecomeActive: nil
                ),
                receivedAt: foreground.addingTimeInterval(1)
            )
        )

        XCTAssertEqual(
            handoff.state,
            .active(.suppressed(.missingDidBecomeActive))
        )
        guard case .suppress(.missingDidBecomeActive) = handoff.action else {
            XCTFail("Expected an unpaired hybrid boundary to be suppressed.")
            return
        }

        let laterActivation = AppStartReducer.reduce(
            state: handoff.state,
            event: .didBecomeActive(foreground.addingTimeInterval(3 * 60 * 60))
        )
        XCTAssertNil(laterActivation.action)
        XCTAssertEqual(laterActivation.state, handoff.state)
    }
}

private func hybridInitialState(
    processStart: Date
) -> AppStartReducer.State {
    .initial(
        AppStartReducer.Evidence(
            processStart: processStart,
            launchOrigin: .unknown,
            didFinishLaunching: nil,
            foregroundBoundary: nil,
            didBecomeActive: nil
        )
    )
}
