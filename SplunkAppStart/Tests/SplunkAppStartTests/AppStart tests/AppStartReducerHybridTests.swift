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

    func testNativeForegroundBoundaryIsPreservedWhenHybridBoundaryIsStale() {
        let start = Date(timeIntervalSinceReferenceDate: 1_850)
        let launch = start.addingTimeInterval(0.1)
        let staleForeground = start.addingTimeInterval(1)
        let nativeForeground = start.addingTimeInterval(3 * 60 * 60)
        let active = nativeForeground.addingTimeInterval(0.4)
        var state = hybridInitialState(processStart: start)

        state =
            AppStartReducer.reduce(
                state: state,
                event: .didFinishLaunching(launch, .background)
            )
            .state
        state =
            AppStartReducer.reduce(
                state: state,
                event: .willEnterForeground(nativeForeground)
            )
            .state
        let result = AppStartReducer.reduce(
            state: state,
            event: .hybridSnapshot(
                AppStartLifecycleSnapshot(
                    launchOrigin: .background,
                    didFinishLaunching: launch,
                    willEnterForeground: staleForeground,
                    didBecomeActive: active
                ),
                receivedAt: nativeForeground.addingTimeInterval(1)
            )
        )

        guard case let .send(span) = result.action else {
            XCTFail("Expected the native foreground boundary to emit a warm start.")
            return
        }

        XCTAssertEqual(result.state, .active(.emitted))
        XCTAssertEqual(span.type, .warm)
        XCTAssertEqual(span.start, nativeForeground)
        XCTAssertEqual(span.end, active)
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

    func testPrewarmActivationWaitsForLateHybridBoundary() {
        let start = Date(timeIntervalSinceReferenceDate: 1_885)
        let launch = start.addingTimeInterval(0.1)
        let foreground = start.addingTimeInterval(1)
        let active = foreground.addingTimeInterval(0.4)
        var state = AppStartReducer.State.initial(
            AppStartReducer.Evidence(
                processStart: start,
                launchOrigin: .prewarmed,
                didFinishLaunching: nil,
                foregroundBoundary: nil,
                didBecomeActive: nil
            )
        )

        // UIKit may report background at launch; prewarm remains authoritative.
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
        guard case let .initial(evidence) = activation.state else {
            XCTFail("Expected activation to wait for the hybrid boundary.")
            return
        }

        XCTAssertEqual(evidence.didBecomeActive, active)
        XCTAssertEqual(evidence.hybridHandoff, .notReceived)

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

    func testPrewarmHandoffBeforeNativeActivationEmitsWarmStart() {
        let start = Date(timeIntervalSinceReferenceDate: 1_886)
        let launch = start.addingTimeInterval(0.1)
        let foreground = start.addingTimeInterval(1)
        let active = foreground.addingTimeInterval(0.4)
        let initial = AppStartReducer.State.initial(
            AppStartReducer.Evidence(
                processStart: start,
                launchOrigin: .prewarmed,
                didFinishLaunching: launch,
                foregroundBoundary: nil,
                didBecomeActive: nil
            )
        )

        let handoff = AppStartReducer.reduce(
            state: initial,
            event: .hybridSnapshot(
                AppStartLifecycleSnapshot(
                    launchOrigin: .background,
                    didFinishLaunching: launch,
                    willEnterForeground: foreground,
                    didBecomeActive: nil
                ),
                receivedAt: foreground.addingTimeInterval(0.1)
            )
        )

        XCTAssertNil(handoff.action)

        let activation = AppStartReducer.reduce(
            state: handoff.state,
            event: .didBecomeActive(active)
        )

        guard case let .send(span) = activation.action else {
            XCTFail("Expected native activation to complete the warm start.")
            return
        }

        XCTAssertEqual(activation.state, .active(.emitted))
        XCTAssertEqual(span.type, .warm)
        XCTAssertEqual(span.start, foreground)
        XCTAssertEqual(span.end, active)
    }

    func testPrewarmActivationWithoutHandoffSuppressesWhenBackgrounded() {
        let start = Date(timeIntervalSinceReferenceDate: 1_887)
        let active = start.addingTimeInterval(1)
        let activation = AppStartReducer.reduce(
            state: .initial(
                AppStartReducer.Evidence(
                    processStart: start,
                    launchOrigin: .prewarmed,
                    didFinishLaunching: start.addingTimeInterval(0.1),
                    foregroundBoundary: nil,
                    didBecomeActive: nil
                )
            ),
            event: .didBecomeActive(active)
        )

        XCTAssertNil(activation.action)

        let background = AppStartReducer.reduce(
            state: activation.state,
            event: .didEnterBackground
        )

        XCTAssertEqual(
            background.state,
            .background(.suppressed(.backgroundWithoutForeground))
        )
        guard case .suppress(.backgroundWithoutForeground) = background.action else {
            XCTFail("Expected unresolved prewarm evidence to fail closed.")
            return
        }
    }

    func testPrewarmActivationWithoutHandoffSuppressesAtTerminationAfterResigningActive() {
        let start = Date(timeIntervalSinceReferenceDate: 1_888)
        let active = start.addingTimeInterval(1)
        let activation = AppStartReducer.reduce(
            state: .initial(
                AppStartReducer.Evidence(
                    processStart: start,
                    launchOrigin: .prewarmed,
                    didFinishLaunching: start.addingTimeInterval(0.1),
                    foregroundBoundary: nil,
                    didBecomeActive: nil
                )
            ),
            event: .didBecomeActive(active)
        )

        XCTAssertNil(activation.action)

        let resigning = AppStartReducer.reduce(
            state: activation.state,
            event: .willResignActive
        )

        XCTAssertNil(resigning.action)

        let termination = AppStartReducer.reduce(
            state: resigning.state,
            event: .willTerminate
        )

        XCTAssertEqual(
            termination.state,
            .stopped(.suppressed(.backgroundWithoutForeground))
        )
        guard case .suppress(.backgroundWithoutForeground) = termination.action else {
            XCTFail("Expected unresolved prewarm evidence to fail closed.")
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
