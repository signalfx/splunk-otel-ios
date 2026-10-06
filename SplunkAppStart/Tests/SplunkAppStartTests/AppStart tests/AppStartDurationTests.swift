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

extension AppStartTests {

    // MARK: - Maximum duration

    func testTrustedForegroundLaunchAtMaximumDurationRemainsCold() throws {
        let processStart = Date(timeIntervalSinceReferenceDate: 1_000)
        let didFinishLaunching = processStart.addingTimeInterval(1)
        let didBecomeActive = processStart.addingTimeInterval(
            AppStartReducer.maximumAppStartDuration
        )
        let (appStart, destination) = configuredAppStart(processStart: processStart)

        appStart.track(
            initialLifecycle: AppStartLifecycleSnapshot(
                launchOrigin: .foreground,
                didFinishLaunching: didFinishLaunching,
                willEnterForeground: nil,
                didBecomeActive: didBecomeActive
            )
        )

        let span = try XCTUnwrap(destination.storedAppStart)
        XCTAssertEqual(span.type, .cold)
        XCTAssertEqual(span.start, processStart)
        XCTAssertEqual(span.end, didBecomeActive)
        XCTAssertEqual(
            span.end.timeIntervalSince(span.start),
            AppStartReducer.maximumAppStartDuration
        )
    }

    func testThirteenHourForegroundLaunchIsSuppressed() {
        let processStart = Date(timeIntervalSinceReferenceDate: 1_500)
        let (appStart, destination) = configuredAppStart(processStart: processStart)

        appStart.track(
            initialLifecycle: AppStartLifecycleSnapshot(
                launchOrigin: .foreground,
                didFinishLaunching: processStart.addingTimeInterval(1),
                willEnterForeground: nil,
                didBecomeActive: processStart.addingTimeInterval(13 * 60 * 60)
            )
        )

        XCTAssertNil(destination.storedAppStart)
        XCTAssertEqual(appStart.suppressionReason, .maxDurationExceeded)
    }

    func testPartialHybridWarmStartCannotExceedMaximumDuration() {
        let processStart = Date(timeIntervalSinceReferenceDate: 1_600)
        let foreground = processStart.addingTimeInterval(13 * 60 * 60)
        let (appStart, destination) = configuredAppStart(processStart: processStart)

        appStart.track(
            initialLifecycle: AppStartLifecycleSnapshot(
                launchOrigin: .background,
                didFinishLaunching: processStart.addingTimeInterval(1),
                willEnterForeground: foreground,
                didBecomeActive: nil
            )
        )
        appStart.process(
            event: .didBecomeActive(
                foreground.addingTimeInterval(
                    AppStartReducer.maximumAppStartDuration + 0.001
                )
            )
        )

        XCTAssertNil(destination.storedAppStart)
        XCTAssertEqual(appStart.suppressionReason, .maxDurationExceeded)
    }

    func testNativeWarmStartCannotExceedMaximumDuration() {
        let processStart = Date(timeIntervalSinceReferenceDate: 1_700)
        let foreground = processStart.addingTimeInterval(13 * 60 * 60)
        let (appStart, destination) = configuredAppStart(processStart: processStart)

        appStart.process(
            event: .didFinishLaunching(
                processStart.addingTimeInterval(0.1),
                .background
            )
        )
        appStart.process(event: .willEnterForeground(foreground))
        appStart.process(
            event: .didBecomeActive(
                foreground.addingTimeInterval(
                    AppStartReducer.maximumAppStartDuration + 0.001
                )
            )
        )

        XCTAssertNil(destination.storedAppStart)
        XCTAssertEqual(appStart.suppressionReason, .maxDurationExceeded)
    }
}
