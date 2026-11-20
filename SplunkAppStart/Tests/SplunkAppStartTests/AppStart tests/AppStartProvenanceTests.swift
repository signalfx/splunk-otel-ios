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

    // MARK: - Launch provenance

    func testNativeBackgroundLaunchWithoutBackgroundNotificationEmitsWarm() {
        let processStart = Date(timeIntervalSinceReferenceDate: 6_000)
        let foreground = processStart.addingTimeInterval(4 * 60 * 60)
        let active = foreground.addingTimeInterval(0.4)
        var state = provenanceInitialState(processStart: processStart)

        for event in [
            AppStartReducer.Event.didFinishLaunching(
                processStart.addingTimeInterval(0.1),
                .background
            ),
            .willEnterForeground(foreground)
        ] {
            state = AppStartReducer.reduce(state: state, event: event).state
        }

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
    }

    func testInterruptedForegroundHandoffUsesResumeBoundary() {
        let processStart = Date(timeIntervalSinceReferenceDate: 6_500)
        let foreground = processStart.addingTimeInterval(3 * 60 * 60)
        let active = foreground.addingTimeInterval(0.5)

        let result = AppStartReducer.reduce(
            state: provenanceInitialState(processStart: processStart),
            event: .hybridSnapshot(
                AppStartLifecycleSnapshot(
                    launchOrigin: .foregroundResumed,
                    didFinishLaunching: processStart.addingTimeInterval(0.1),
                    willEnterForeground: foreground,
                    didBecomeActive: active
                ),
                receivedAt: active.addingTimeInterval(1)
            )
        )

        guard case let .send(span) = result.action else {
            XCTFail("Expected a resumed foreground activation.")
            return
        }

        XCTAssertEqual(span.type, .warm)
        XCTAssertEqual(span.start, foreground)
        XCTAssertEqual(span.end, active)
    }

    func testForegroundHandoffWithResumeBoundaryIsSuppressed() {
        let processStart = Date(timeIntervalSinceReferenceDate: 7_000)
        let foreground = processStart.addingTimeInterval(3 * 60 * 60)

        let result = AppStartReducer.reduce(
            state: provenanceInitialState(processStart: processStart),
            event: .hybridSnapshot(
                AppStartLifecycleSnapshot(
                    launchOrigin: .foreground,
                    didFinishLaunching: processStart.addingTimeInterval(0.1),
                    willEnterForeground: foreground,
                    didBecomeActive: foreground.addingTimeInterval(0.5)
                ),
                receivedAt: foreground.addingTimeInterval(1)
            )
        )

        XCTAssertEqual(
            result.state,
            .active(.suppressed(.conflictingLaunchOrigin))
        )
        guard case .suppress(.conflictingLaunchOrigin) = result.action else {
            XCTFail("Expected inconsistent foreground provenance to be suppressed.")
            return
        }
    }

    func testBackgroundAsFirstObservationDropsAmbiguousActivation() {
        let processStart = Date(timeIntervalSinceReferenceDate: 7_500)
        let foreground = processStart.addingTimeInterval(2 * 60 * 60)
        let active = foreground.addingTimeInterval(0.25)
        var state = provenanceInitialState(processStart: processStart)

        let background = AppStartReducer.reduce(
            state: state,
            event: .didEnterBackground
        )
        state = background.state

        XCTAssertEqual(
            background.state,
            .background(.unobservedInitialActivation(.unknownLaunchOrigin))
        )
        guard case .suppress(.unknownLaunchOrigin) = background.action else {
            XCTFail("Expected the unobserved initial activation to be suppressed.")
            return
        }

        let foregroundResult = AppStartReducer.reduce(
            state: state,
            event: .willEnterForeground(foreground)
        )
        state = foregroundResult.state
        let result = AppStartReducer.reduce(
            state: state,
            event: .didBecomeActive(active)
        )

        XCTAssertNil(result.action)
        XCTAssertEqual(
            result.state,
            .active(.suppressed(.unknownLaunchOrigin))
        )
    }

    func testMatchingNativeAndHybridBackgroundEvidenceIsOrderIndependent() {
        let processStart = Date(timeIntervalSinceReferenceDate: 7_750)
        let launch = processStart.addingTimeInterval(0.1)
        let foreground = processStart.addingTimeInterval(2 * 60 * 60)
        let active = foreground.addingTimeInterval(0.25)
        let nativeLaunch = AppStartReducer.Event.didFinishLaunching(
            launch,
            .background
        )
        let hybridSnapshot = AppStartReducer.Event.hybridSnapshot(
            AppStartLifecycleSnapshot(
                launchOrigin: .background,
                didFinishLaunching: launch,
                willEnterForeground: nil,
                didBecomeActive: nil
            ),
            receivedAt: launch.addingTimeInterval(1)
        )

        for evidenceOrder in [
            [nativeLaunch, hybridSnapshot],
            [hybridSnapshot, nativeLaunch]
        ] {
            var state = provenanceInitialState(processStart: processStart)

            for event in evidenceOrder + [
                .willEnterForeground(foreground),
                .didBecomeActive(active)
            ] {
                state = AppStartReducer.reduce(state: state, event: event).state
            }

            XCTAssertEqual(state, .active(.emitted))
        }
    }

    func testUnknownNativeLaunchEvidenceCannotBecomeCold() {
        let processStart = Date(timeIntervalSinceReferenceDate: 7_900)
        let foreground = processStart.addingTimeInterval(3 * 60 * 60)
        let active = foreground.addingTimeInterval(0.2)
        var state = provenanceInitialState(processStart: processStart)

        for event in [
            AppStartReducer.Event.didFinishLaunching(
                processStart.addingTimeInterval(0.1),
                .unknown
            ),
            .willEnterForeground(foreground)
        ] {
            state = AppStartReducer.reduce(state: state, event: event).state
        }

        let result = AppStartReducer.reduce(
            state: state,
            event: .didBecomeActive(active)
        )

        XCTAssertEqual(
            result.state,
            .active(.suppressed(.unknownLaunchOrigin))
        )
        guard case .suppress(.unknownLaunchOrigin) = result.action else {
            XCTFail("Expected unknown native provenance to be suppressed.")
            return
        }
    }
}

extension AppStartTests {

    // MARK: - Hybrid provenance

    func testInterruptedForegroundHybridHandoffExcludesBackgroundResidence() throws {
        let processStart = Date(timeIntervalSinceReferenceDate: 8_000)
        let foreground = processStart.addingTimeInterval(5 * 60 * 60)
        let active = foreground.addingTimeInterval(0.3)
        let (appStart, destination) = configuredAppStart(processStart: processStart)

        appStart.track(
            initialLifecycle: AppStartLifecycleSnapshot(
                launchOrigin: .foregroundResumed,
                didFinishLaunching: processStart.addingTimeInterval(0.1),
                willEnterForeground: foreground,
                didBecomeActive: active
            )
        )

        let span = try XCTUnwrap(destination.storedAppStart)
        XCTAssertEqual(span.type, .warm)
        XCTAssertEqual(span.start, foreground)
        XCTAssertEqual(span.end, active)
        XCTAssertEqual(span.end.timeIntervalSince(span.start), 0.3, accuracy: 0.000001)
    }
}

private func provenanceInitialState(
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
