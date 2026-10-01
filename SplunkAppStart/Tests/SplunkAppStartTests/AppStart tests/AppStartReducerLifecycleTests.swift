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

    // MARK: - Ambiguous evidence

    func testActivationWithoutLaunchEvidenceDoesNotGuessOrigin() {
        let start = Date(timeIntervalSinceReferenceDate: 2_000)
        var state = initialState(processStart: start)

        let activationResult = AppStartReducer.reduce(
            state: state,
            event: .didBecomeActive(start.addingTimeInterval(1))
        )
        state = activationResult.state

        guard case let .initial(evidence) = state else {
            XCTFail("An activation without launch evidence must stay pending.")
            return
        }

        XCTAssertEqual(evidence.launchOrigin, .unknown)
    }

    func testUnknownActivationIsSuppressedWhenObservationBecomesConclusive() {
        let start = Date(timeIntervalSinceReferenceDate: 2_500)
        let activation = AppStartReducer.reduce(
            state: initialState(processStart: start),
            event: .didBecomeActive(start.addingTimeInterval(1))
        )

        guard case .initial = activation.state else {
            XCTFail("Unknown evidence must remain pending while the app is active.")
            return
        }

        XCTAssertNil(activation.action)

        let resigned = AppStartReducer.reduce(
            state: activation.state,
            event: .willResignActive
        )

        XCTAssertEqual(
            resigned.state,
            .background(.suppressed(.unknownLaunchOrigin))
        )
        guard case .suppress(.unknownLaunchOrigin) = resigned.action else {
            XCTFail("Expected unknown initial evidence to be suppressed.")
            return
        }
    }

    func testHybridCompletionSuppressesUnknownOrigin() {
        let start = Date(timeIntervalSinceReferenceDate: 3_000)
        let result = AppStartReducer.reduce(
            state: initialState(processStart: start),
            event: .hybridSnapshot(
                AppStartLifecycleSnapshot(
                    launchOrigin: .unknown,
                    didFinishLaunching: nil,
                    willEnterForeground: nil,
                    didBecomeActive: start.addingTimeInterval(1)
                ),
                receivedAt: start.addingTimeInterval(2)
            )
        )

        XCTAssertEqual(
            result.state,
            .active(.suppressed(.unknownLaunchOrigin))
        )

        guard case .suppress(.unknownLaunchOrigin) = result.action else {
            XCTFail("Expected an unknown-origin suppression.")
            return
        }
    }

    func testIncompleteUnknownHandoffCannotBecomeLongColdStart() {
        let start = Date(timeIntervalSinceReferenceDate: 3_500)
        let foreground = start.addingTimeInterval(4 * 60 * 60)
        let active = foreground.addingTimeInterval(0.4)
        var state = initialState(processStart: start)

        state =
            AppStartReducer.reduce(
                state: state,
                event: .hybridSnapshot(
                    AppStartLifecycleSnapshot(
                        launchOrigin: .unknown,
                        didFinishLaunching: start.addingTimeInterval(0.1),
                        willEnterForeground: nil,
                        didBecomeActive: nil
                    ),
                    receivedAt: start.addingTimeInterval(1)
                )
            )
            .state
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

        XCTAssertEqual(
            result.state,
            .active(.suppressed(.unknownLaunchOrigin))
        )
        guard case .suppress(.unknownLaunchOrigin) = result.action else {
            XCTFail("Expected ambiguous hybrid evidence to be suppressed.")
            return
        }
    }

    func testHybridTimestampAfterHandoffIsSuppressed() {
        let start = Date(timeIntervalSinceReferenceDate: 3_750)
        let receivedAt = start.addingTimeInterval(1)
        let result = AppStartReducer.reduce(
            state: initialState(processStart: start),
            event: .hybridSnapshot(
                AppStartLifecycleSnapshot(
                    launchOrigin: .foreground,
                    didFinishLaunching: start.addingTimeInterval(0.1),
                    willEnterForeground: nil,
                    didBecomeActive: receivedAt.addingTimeInterval(1)
                ),
                receivedAt: receivedAt
            )
        )

        XCTAssertEqual(
            result.state,
            .active(.suppressed(.invalidTimestampOrder))
        )
        guard case .suppress(.invalidTimestampOrder) = result.action else {
            XCTFail("Expected a future imported timestamp to be suppressed.")
            return
        }
    }

    func testExporterTimestampRangeIsValidated() {
        XCTAssertFalse(AppStartReducer.valid(.distantPast))
        XCTAssertFalse(AppStartReducer.valid(.distantFuture))
        XCTAssertTrue(AppStartReducer.valid(Date()))
    }


    // MARK: - Subsequent activations

    func testHotSequenceUsesForegroundBoundary() {
        let foreground = Date(timeIntervalSinceReferenceDate: 4_000)
        let active = foreground.addingTimeInterval(0.25)
        var state = AppStartReducer.State.active(.emitted)

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

        XCTAssertEqual(result.state, .active(.emitted))

        guard case let .send(span) = result.action else {
            XCTFail("Expected a hot AppStart.")
            return
        }

        XCTAssertEqual(span.type, .hot)
        XCTAssertEqual(span.start, foreground)
        XCTAssertEqual(span.end, active)
    }

    func testObservationGapDiscardsInFlightForegroundBoundary() {
        let staleForeground = Date(timeIntervalSinceReferenceDate: 4_500)
        let activeAfterGap = staleForeground.addingTimeInterval(3 * 60 * 60)
        let nextForeground = activeAfterGap.addingTimeInterval(10)
        let nextActive = nextForeground.addingTimeInterval(0.25)
        var state = AppStartReducer.State.background(.emitted)

        state =
            AppStartReducer.reduce(
                state: state,
                event: .willEnterForeground(staleForeground)
            )
            .state
        state =
            AppStartReducer.reduce(
                state: state,
                event: .observationGap
            )
            .state

        let discarded = AppStartReducer.reduce(
            state: state,
            event: .didBecomeActive(activeAfterGap)
        )
        XCTAssertNil(discarded.action)
        XCTAssertEqual(discarded.state, .active(.emitted))
        state = discarded.state

        for event in [
            AppStartReducer.Event.willResignActive,
            .didEnterBackground,
            .willEnterForeground(nextForeground)
        ] {
            state = AppStartReducer.reduce(state: state, event: event).state
        }

        let result = AppStartReducer.reduce(
            state: state,
            event: .didBecomeActive(nextActive)
        )

        guard case let .send(span) = result.action else {
            XCTFail("Expected the next fully observed activation to be emitted.")
            return
        }

        XCTAssertEqual(span.type, .hot)
        XCTAssertEqual(span.start, nextForeground)
        XCTAssertEqual(span.end, nextActive)
    }

    func testRepeatedForegroundBoundaryDropsAmbiguousActivation() {
        let firstForeground = Date(timeIntervalSinceReferenceDate: 4_750)
        let repeatedForeground = firstForeground.addingTimeInterval(3 * 60 * 60)
        let ambiguousActive = repeatedForeground.addingTimeInterval(0.25)
        var state = AppStartReducer.State.background(.emitted)

        state =
            AppStartReducer.reduce(
                state: state,
                event: .willEnterForeground(firstForeground)
            )
            .state
        let repeated = AppStartReducer.reduce(
            state: state,
            event: .willEnterForeground(repeatedForeground)
        )
        state = repeated.state

        guard case .suppress(.conflictingLifecycleEvidence) = repeated.action else {
            XCTFail("Expected repeated foreground evidence to be suppressed.")
            return
        }

        let discarded = AppStartReducer.reduce(
            state: state,
            event: .didBecomeActive(ambiguousActive)
        )
        XCTAssertNil(discarded.action)
        XCTAssertEqual(
            discarded.state,
            .active(.suppressed(.conflictingLifecycleEvidence))
        )
    }

    func testRepeatedInitialNativeForegroundBoundaryDropsActivation() {
        let start = Date(timeIntervalSinceReferenceDate: 4_800)
        let firstForeground = start.addingTimeInterval(1)
        let repeatedForeground = start.addingTimeInterval(3 * 60 * 60)
        var state = initialState(processStart: start)

        for event in [
            AppStartReducer.Event.didFinishLaunching(
                start.addingTimeInterval(0.1),
                .background
            ),
            .willEnterForeground(firstForeground)
        ] {
            state = AppStartReducer.reduce(state: state, event: event).state
        }

        let repeated = AppStartReducer.reduce(
            state: state,
            event: .willEnterForeground(repeatedForeground)
        )
        guard case .suppress(.conflictingLifecycleEvidence) = repeated.action else {
            XCTFail("Expected repeated initial foreground evidence to be suppressed.")
            return
        }

        let completion = AppStartReducer.reduce(
            state: repeated.state,
            event: .didBecomeActive(repeatedForeground.addingTimeInterval(0.4))
        )
        XCTAssertNil(completion.action)
        XCTAssertEqual(
            completion.state,
            .active(.suppressed(.conflictingLifecycleEvidence))
        )
    }

    func testObservationGapSuppressesUnresolvedInitialEvidence() {
        let start = Date(timeIntervalSinceReferenceDate: 5_000)
        let staleLaunch = start.addingTimeInterval(0.1)
        let foreground = start.addingTimeInterval(3 * 60 * 60)
        let active = foreground.addingTimeInterval(0.3)
        var state = initialState(processStart: start)

        let launchResult = AppStartReducer.reduce(
            state: state,
            event: .didFinishLaunching(staleLaunch, .foreground)
        )
        state = launchResult.state
        let gap = AppStartReducer.reduce(
            state: state,
            event: .observationGap
        )
        state = gap.state

        XCTAssertEqual(
            gap.state,
            .background(.unobservedInitialActivation(.observationGap))
        )
        guard case .suppress(.observationGap) = gap.action else {
            XCTFail("Expected unresolved evidence to be invalidated.")
            return
        }

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

        XCTAssertNil(result.action)
        XCTAssertEqual(
            result.state,
            .active(.suppressed(.observationGap))
        )
    }
}

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
