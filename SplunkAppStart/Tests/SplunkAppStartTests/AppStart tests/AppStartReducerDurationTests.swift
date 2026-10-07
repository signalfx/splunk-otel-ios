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

@testable import SplunkAppStart

extension AppStartReducerTests {

    // MARK: - Maximum duration

    func testMaximumDurationIsTenSeconds() {
        XCTAssertEqual(AppStartReducer.maximumAppStartDuration, 10)
    }

    func testColdStartJustBelowMaximumDurationIsEmitted() {
        let processStart = Date(timeIntervalSinceReferenceDate: 19_000)
        let result = AppStartReducer.reduce(
            state: durationInitialState(
                processStart: processStart,
                launchOrigin: .foreground
            ),
            event: .didBecomeActive(
                processStart.addingTimeInterval(
                    AppStartReducer.maximumAppStartDuration - 0.001
                )
            )
        )

        guard case let .send(span) = result.action else {
            XCTFail("Expected a cold AppStart below the maximum duration.")
            return
        }

        XCTAssertEqual(span.type, .cold)
        XCTAssertLessThan(
            span.end.timeIntervalSince(span.start),
            AppStartReducer.maximumAppStartDuration
        )
    }

    func testColdStartAtMaximumDurationIsEmitted() {
        let processStart = Date(timeIntervalSinceReferenceDate: 19_100)
        let result = AppStartReducer.reduce(
            state: durationInitialState(
                processStart: processStart,
                launchOrigin: .foreground
            ),
            event: .didBecomeActive(
                processStart.addingTimeInterval(
                    AppStartReducer.maximumAppStartDuration
                )
            )
        )

        guard case let .send(span) = result.action else {
            XCTFail("Expected a cold AppStart at the maximum duration.")
            return
        }

        XCTAssertEqual(span.type, .cold)
        XCTAssertEqual(
            span.end.timeIntervalSince(span.start),
            AppStartReducer.maximumAppStartDuration
        )
    }

    func testColdStartCannotExceedMaximumDuration() {
        let processStart = Date(timeIntervalSinceReferenceDate: 19_200)
        let result = AppStartReducer.reduce(
            state: durationInitialState(
                processStart: processStart,
                launchOrigin: .foreground
            ),
            event: .didBecomeActive(
                processStart.addingTimeInterval(
                    AppStartReducer.maximumAppStartDuration + 0.001
                )
            )
        )

        XCTAssertEqual(
            result.state,
            .active(.suppressed(.maxDurationExceeded))
        )
        guard case .suppress(.maxDurationExceeded) = result.action else {
            XCTFail("Expected an overlong cold AppStart to be suppressed.")
            return
        }
    }

    func testLongBackgroundResidenceIsExcludedFromWarmDuration() {
        let processStart = Date(timeIntervalSinceReferenceDate: 20_000)
        let foreground = processStart.addingTimeInterval(13 * 60 * 60)
        let active = foreground.addingTimeInterval(0.25)
        var state = durationInitialState(
            processStart: processStart,
            launchOrigin: .background
        )

        state =
            AppStartReducer.reduce(
                state: state,
                event: .willEnterForeground(foreground)
            )
            .state
        let result = AppStartReducer.reduce(
            state: state,
            event: .didBecomeActive(active)
        )

        guard case let .send(span) = result.action else {
            XCTFail("Expected a boundary-bounded warm AppStart.")
            return
        }

        XCTAssertEqual(span.type, .warm)
        XCTAssertEqual(span.start, foreground)
        XCTAssertEqual(span.end, active)
        XCTAssertEqual(
            span.end.timeIntervalSince(span.start),
            0.25,
            accuracy: 0.000001
        )
    }

    func testWarmStartAtMaximumDurationIsEmitted() {
        let processStart = Date(timeIntervalSinceReferenceDate: 20_500)
        let foreground = processStart.addingTimeInterval(13 * 60 * 60)
        var state = durationInitialState(
            processStart: processStart,
            launchOrigin: .background
        )

        state =
            AppStartReducer.reduce(
                state: state,
                event: .willEnterForeground(foreground)
            )
            .state
        let result = AppStartReducer.reduce(
            state: state,
            event: .didBecomeActive(
                foreground.addingTimeInterval(
                    AppStartReducer.maximumAppStartDuration
                )
            )
        )

        guard case let .send(span) = result.action else {
            XCTFail("Expected a warm AppStart at the maximum duration.")
            return
        }

        XCTAssertEqual(span.type, .warm)
        XCTAssertEqual(
            span.end.timeIntervalSince(span.start),
            AppStartReducer.maximumAppStartDuration
        )
    }

    func testWarmStartCannotExceedMaximumDuration() {
        let processStart = Date(timeIntervalSinceReferenceDate: 21_000)
        let foreground = processStart.addingTimeInterval(13 * 60 * 60)
        var state = durationInitialState(
            processStart: processStart,
            launchOrigin: .background
        )

        state =
            AppStartReducer.reduce(
                state: state,
                event: .willEnterForeground(foreground)
            )
            .state
        let result = AppStartReducer.reduce(
            state: state,
            event: .didBecomeActive(
                foreground.addingTimeInterval(
                    AppStartReducer.maximumAppStartDuration + 0.001
                )
            )
        )

        XCTAssertEqual(
            result.state,
            .active(.suppressed(.maxDurationExceeded))
        )
        guard case .suppress(.maxDurationExceeded) = result.action else {
            XCTFail("Expected an overlong warm AppStart to be suppressed.")
            return
        }
    }

    func testForegroundResumedStartAtMaximumDurationIsEmitted() {
        let processStart = Date(timeIntervalSinceReferenceDate: 21_250)
        let foreground = processStart.addingTimeInterval(13 * 60 * 60)
        var state = durationInitialState(
            processStart: processStart,
            launchOrigin: .foregroundResumed
        )

        state =
            AppStartReducer.reduce(
                state: state,
                event: .willEnterForeground(foreground)
            )
            .state
        let result = AppStartReducer.reduce(
            state: state,
            event: .didBecomeActive(
                foreground.addingTimeInterval(
                    AppStartReducer.maximumAppStartDuration
                )
            )
        )

        guard case let .send(span) = result.action else {
            XCTFail("Expected a resumed AppStart at the maximum duration.")
            return
        }

        XCTAssertEqual(span.type, .warm)
        XCTAssertEqual(
            span.end.timeIntervalSince(span.start),
            AppStartReducer.maximumAppStartDuration
        )
    }

    func testForegroundResumedStartCannotExceedMaximumDuration() {
        let processStart = Date(timeIntervalSinceReferenceDate: 21_500)
        let foreground = processStart.addingTimeInterval(13 * 60 * 60)
        var state = durationInitialState(
            processStart: processStart,
            launchOrigin: .foregroundResumed
        )

        state =
            AppStartReducer.reduce(
                state: state,
                event: .willEnterForeground(foreground)
            )
            .state
        let result = AppStartReducer.reduce(
            state: state,
            event: .didBecomeActive(
                foreground.addingTimeInterval(
                    AppStartReducer.maximumAppStartDuration + 0.001
                )
            )
        )

        XCTAssertEqual(
            result.state,
            .active(.suppressed(.maxDurationExceeded))
        )
        guard case .suppress(.maxDurationExceeded) = result.action else {
            XCTFail("Expected an overlong resumed AppStart to be suppressed.")
            return
        }
    }

    func testHotStartAtMaximumDurationIsEmitted() {
        let foreground = Date(timeIntervalSinceReferenceDate: 21_750)
        let foregrounding = AppStartReducer.reduce(
            state: .background(.emitted),
            event: .willEnterForeground(foreground)
        )
        let result = AppStartReducer.reduce(
            state: foregrounding.state,
            event: .didBecomeActive(
                foreground.addingTimeInterval(
                    AppStartReducer.maximumAppStartDuration
                )
            )
        )

        guard case let .send(span) = result.action else {
            XCTFail("Expected a hot AppStart at the maximum duration.")
            return
        }

        XCTAssertEqual(result.state, .active(.emitted))
        XCTAssertEqual(span.type, .hot)
        XCTAssertEqual(
            span.end.timeIntervalSince(span.start),
            AppStartReducer.maximumAppStartDuration
        )
    }

    func testHotStartCannotExceedMaximumDuration() {
        let foreground = Date(timeIntervalSinceReferenceDate: 22_000)
        let foregrounding = AppStartReducer.reduce(
            state: .background(.emitted),
            event: .willEnterForeground(foreground)
        )
        let result = AppStartReducer.reduce(
            state: foregrounding.state,
            event: .didBecomeActive(
                foreground.addingTimeInterval(13 * 60 * 60)
            )
        )

        // Suppression applies only to this activation. The already-emitted
        // initial resolution remains intact so later hot starts can be measured.
        XCTAssertEqual(result.state, .active(.emitted))
        guard case .suppress(.maxDurationExceeded) = result.action else {
            XCTFail("Expected an overlong hot AppStart to be suppressed.")
            return
        }
    }

    func testValidHotStartAfterOverlongHotStartIsStillEmitted() {
        let firstForeground = Date(timeIntervalSinceReferenceDate: 23_000)
        var state =
            AppStartReducer.reduce(
                state: .background(.emitted),
                event: .willEnterForeground(firstForeground)
            )
            .state
        state =
            AppStartReducer.reduce(
                state: state,
                event: .didBecomeActive(
                    firstForeground.addingTimeInterval(13 * 60 * 60)
                )
            )
            .state
        state =
            AppStartReducer.reduce(
                state: state,
                event: .didEnterBackground
            )
            .state

        let secondForeground = firstForeground.addingTimeInterval(14 * 60 * 60)
        state =
            AppStartReducer.reduce(
                state: state,
                event: .willEnterForeground(secondForeground)
            )
            .state
        let result = AppStartReducer.reduce(
            state: state,
            event: .didBecomeActive(secondForeground.addingTimeInterval(0.2))
        )

        guard case let .send(span) = result.action else {
            XCTFail("Expected the next valid hot AppStart to be emitted.")
            return
        }

        XCTAssertEqual(span.type, .hot)
        XCTAssertEqual(span.start, secondForeground)
        XCTAssertEqual(
            span.end.timeIntervalSince(span.start),
            0.2,
            accuracy: 0.000001
        )
    }
}

private func durationInitialState(
    processStart: Date,
    launchOrigin: AppStartReducer.LaunchOrigin
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
