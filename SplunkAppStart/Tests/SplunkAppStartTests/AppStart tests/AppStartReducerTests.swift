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

final class AppStartReducerTests: XCTestCase {

    // MARK: - Initial resolution

    func testForegroundSequenceTransitionsToEmitted() {
        let start = Date(timeIntervalSinceReferenceDate: 1_000)
        let active = start.addingTimeInterval(1)
        var state = initialState(processStart: start)

        let launchResult = AppStartReducer.reduce(
            state: state,
            event: .didFinishLaunching(
                start.addingTimeInterval(0.1),
                .foreground
            )
        )
        state = launchResult.state
        let result = AppStartReducer.reduce(
            state: state,
            event: .didBecomeActive(active)
        )

        XCTAssertEqual(result.0, .active(.emitted))

        guard case let .send(span) = result.1 else {
            XCTFail("Expected a send action.")
            return
        }

        XCTAssertEqual(span.type, .cold)
        XCTAssertEqual(span.start, start)
        XCTAssertEqual(span.end, active)
    }

    func testBackgroundTransitionBeforeForegroundEmitsWarm() {
        let start = Date(timeIntervalSinceReferenceDate: 1_500)
        let foreground = start.addingTimeInterval(3 * 60 * 60)
        let active = foreground.addingTimeInterval(0.4)
        var state = initialState(processStart: start)

        let launchResult = AppStartReducer.reduce(
            state: state,
            event: .didFinishLaunching(
                start.addingTimeInterval(0.1),
                .foreground
            )
        )
        state = launchResult.state

        let resignResult = AppStartReducer.reduce(
            state: state,
            event: .willResignActive
        )
        state = resignResult.state

        XCTAssertNil(resignResult.action)
        XCTAssertEqual(resignResult.state, launchResult.state)

        let backgroundResult = AppStartReducer.reduce(
            state: state,
            event: .didEnterBackground
        )
        state = backgroundResult.state

        let foregroundResult = AppStartReducer.reduce(
            state: state,
            event: .willEnterForeground(foreground)
        )
        state = foregroundResult.state

        let result = AppStartReducer.reduce(
            state: state,
            event: .didBecomeActive(active)
        )

        guard case let .send(span) = result.action else {
            XCTFail("Expected a warm AppStart.")
            return
        }

        XCTAssertEqual(span.type, .warm)
        XCTAssertEqual(span.start, foreground)
        XCTAssertEqual(span.end, active)
    }

    func testInterruptedForegroundAttemptUsesNextForegroundBoundary() {
        let start = Date(timeIntervalSinceReferenceDate: 1_700)
        let interruptedForeground = start.addingTimeInterval(1)
        let nextForeground = start.addingTimeInterval(3 * 60 * 60)
        let active = nextForeground.addingTimeInterval(0.4)
        var state = initialState(processStart: start)

        for event in [
            AppStartReducer.Event.didFinishLaunching(
                start.addingTimeInterval(0.1),
                .foreground
            ),
            .willEnterForeground(interruptedForeground),
            .didEnterBackground,
            .willEnterForeground(nextForeground)
        ] {
            state = AppStartReducer.reduce(state: state, event: event).state
        }

        let result = AppStartReducer.reduce(
            state: state,
            event: .didBecomeActive(active)
        )

        guard case let .send(span) = result.action else {
            XCTFail("Expected a warm AppStart.")
            return
        }

        XCTAssertEqual(span.type, .warm)
        XCTAssertEqual(span.start, nextForeground)
        XCTAssertEqual(span.end, active)
    }

    func testInterruptedPrewarmUsesNextForegroundBoundary() {
        let start = Date(timeIntervalSinceReferenceDate: 1_800)
        let interruptedForeground = start.addingTimeInterval(1)
        let nextForeground = start.addingTimeInterval(3 * 60 * 60)
        let active = nextForeground.addingTimeInterval(0.4)
        var state = initialState(processStart: start, launchOrigin: .prewarmed)

        for event in [
            AppStartReducer.Event.willEnterForeground(interruptedForeground),
            .willResignActive,
            .didEnterBackground,
            .willEnterForeground(nextForeground)
        ] {
            state = AppStartReducer.reduce(state: state, event: event).state
        }

        let result = AppStartReducer.reduce(
            state: state,
            event: .didBecomeActive(active)
        )

        guard case let .send(span) = result.action else {
            XCTFail("Expected a warm AppStart.")
            return
        }

        XCTAssertEqual(span.type, .warm)
        XCTAssertEqual(span.start, nextForeground)
        XCTAssertEqual(span.end, active)
    }

    func testLateObservationOfActiveAppSuppressesInitialAndNextReentryIsHot() {
        let start = Date(timeIntervalSinceReferenceDate: 1_900)
        let foreground = start.addingTimeInterval(3 * 60 * 60)
        let active = foreground.addingTimeInterval(0.4)
        var state = initialState(processStart: start)

        let resigned = AppStartReducer.reduce(
            state: state,
            event: .willResignActive
        )
        state = resigned.state

        XCTAssertEqual(
            resigned.state,
            .background(.suppressed(.unknownLaunchOrigin))
        )
        guard case .suppress(.unknownLaunchOrigin) = resigned.action else {
            XCTFail("Expected the unobserved initial activation to be suppressed.")
            return
        }

        for event in [
            AppStartReducer.Event.didEnterBackground,
            .willEnterForeground(foreground)
        ] {
            state = AppStartReducer.reduce(state: state, event: event).state
        }

        let result = AppStartReducer.reduce(
            state: state,
            event: .didBecomeActive(active)
        )

        guard case let .send(span) = result.action else {
            XCTFail("Expected a hot AppStart.")
            return
        }

        XCTAssertEqual(span.type, .hot)
        XCTAssertEqual(span.start, foreground)
        XCTAssertEqual(span.end, active)
    }

    func testLateInitialActivationCannotBecomeFalseHotStart() {
        let start = Date(timeIntervalSinceReferenceDate: 1_950)
        let firstActive = start.addingTimeInterval(1)
        let foreground = firstActive.addingTimeInterval(3 * 60 * 60)
        let nextActive = foreground.addingTimeInterval(0.4)
        var state = initialState(processStart: start)

        let initialActivation = AppStartReducer.reduce(
            state: state,
            event: .didBecomeActive(firstActive)
        )
        state = initialActivation.state

        let foregroundResult = AppStartReducer.reduce(
            state: state,
            event: .willEnterForeground(foreground)
        )
        guard case .suppress(.unknownLaunchOrigin) = foregroundResult.action else {
            XCTFail("Expected unknown initial evidence to be suppressed.")
            return
        }

        let completion = AppStartReducer.reduce(
            state: foregroundResult.state,
            event: .didBecomeActive(nextActive)
        )

        XCTAssertNil(completion.action)
        XCTAssertEqual(
            completion.state,
            .active(.suppressed(.unknownLaunchOrigin))
        )
    }

    func testActivationWithoutForegroundBoundaryIsDiscarded() {
        let active = Date(timeIntervalSinceReferenceDate: 1_975)
        let result = AppStartReducer.reduce(
            state: .background(.emitted),
            event: .didBecomeActive(active)
        )

        XCTAssertNil(result.action)
        XCTAssertEqual(result.state, .active(.emitted))
    }

    // MARK: - Helpers

    private func initialState(
        processStart: Date,
        launchOrigin: AppStartReducer.LaunchOrigin = .unknown
    ) -> AppStartReducer.State {
        .initial(
            AppStartReducer.Evidence(
                processStart: processStart,
                launchOrigin: launchOrigin,
                didFinishLaunching: nil,
                foregroundBoundary: nil,
                didBecomeActive: nil
            )
        )
    }
}
