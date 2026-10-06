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

    func testPartialHybridBoundaryPairsWithNativeActivation() {
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

        XCTAssertNil(handoff.action)
        guard case let .initial(evidence) = handoff.state else {
            XCTFail("Expected a partial hybrid activation to remain pending.")
            return
        }

        XCTAssertEqual(evidence.launchOrigin, .background)
        XCTAssertEqual(evidence.foregroundBoundary, .hybrid(foreground))
        XCTAssertEqual(evidence.hybridHandoff, .received)

        let active = foreground.addingTimeInterval(0.4)
        let completion = AppStartReducer.reduce(
            state: handoff.state,
            event: .didBecomeActive(active)
        )

        XCTAssertEqual(completion.state, .active(.emitted))
        guard case let .send(span) = completion.action else {
            XCTFail("Expected native activation to complete the hybrid warm start.")
            return
        }

        XCTAssertEqual(span.type, .warm)
        XCTAssertEqual(span.start, foreground)
        XCTAssertEqual(span.end, active)
    }

    func testPartialHybridBoundaryIsClearedWhenActivationIsAborted() {
        let start = Date(timeIntervalSinceReferenceDate: 1_895)
        let interruptedForeground = start.addingTimeInterval(1)
        let resumedForeground = start.addingTimeInterval(10)
        let active = resumedForeground.addingTimeInterval(0.4)
        var state =
            AppStartReducer.reduce(
                state: hybridInitialState(processStart: start),
                event: .hybridSnapshot(
                    AppStartLifecycleSnapshot(
                        launchOrigin: .background,
                        didFinishLaunching: start.addingTimeInterval(0.1),
                        willEnterForeground: interruptedForeground,
                        didBecomeActive: nil
                    ),
                    receivedAt: interruptedForeground.addingTimeInterval(1)
                )
            )
            .state

        for event in [
            AppStartReducer.Event.didEnterBackground,
            .willEnterForeground(resumedForeground)
        ] {
            state = AppStartReducer.reduce(state: state, event: event).state
        }

        let completion = AppStartReducer.reduce(
            state: state,
            event: .didBecomeActive(active)
        )

        guard case let .send(span) = completion.action else {
            XCTFail("Expected the resumed activation to emit a warm start.")
            return
        }

        XCTAssertEqual(span.type, .warm)
        XCTAssertEqual(span.start, resumedForeground)
        XCTAssertEqual(span.end, active)
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
