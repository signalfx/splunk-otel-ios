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

    // MARK: - Hot starts

    func testHotStartAfterInitialEmission() throws {
        let processStart = Date(timeIntervalSinceReferenceDate: 11_000)
        let firstActive = processStart.addingTimeInterval(1)
        let foreground = firstActive.addingTimeInterval(10)
        let secondActive = foreground.addingTimeInterval(0.25)
        let (appStart, destination) = configuredAppStart(processStart: processStart)

        appStart.track(
            initialLifecycle: AppStartLifecycleSnapshot(
                launchOrigin: .foreground,
                didFinishLaunching: processStart.addingTimeInterval(0.1),
                willEnterForeground: nil,
                didBecomeActive: firstActive
            )
        )
        appStart.process(event: .didEnterBackground)
        appStart.process(event: .willEnterForeground(foreground))
        appStart.process(event: .didBecomeActive(secondActive))

        XCTAssertEqual(destination.storedAppStarts.count, 2)
        let hot = try XCTUnwrap(destination.storedAppStarts.last)
        XCTAssertEqual(hot.type, .hot)
        XCTAssertEqual(hot.start, foreground)
        XCTAssertEqual(hot.end, secondActive)
    }

    func testHotStartStillWorksAfterAmbiguousInitialSuppression() throws {
        let processStart = Date(timeIntervalSinceReferenceDate: 12_000)
        let foreground = processStart.addingTimeInterval(20)
        let active = foreground.addingTimeInterval(0.2)
        let (appStart, destination) = configuredAppStart(processStart: processStart)

        appStart.track(
            didBecomeActive: processStart.addingTimeInterval(1),
            didFinishLaunching: nil,
            willEnterForeground: nil
        )
        appStart.process(event: .didEnterBackground)
        appStart.process(event: .willEnterForeground(foreground))
        appStart.process(event: .didBecomeActive(active))

        XCTAssertEqual(destination.storedAppStarts.count, 1)
        let hot = try XCTUnwrap(destination.storedAppStart)
        XCTAssertEqual(hot.type, .hot)
        XCTAssertEqual(hot.start, foreground)
        XCTAssertEqual(hot.end, active)
    }

    func testTemporaryInactiveStateDoesNotEmitHotStart() {
        let processStart = Date(timeIntervalSinceReferenceDate: 13_000)
        let firstActive = processStart.addingTimeInterval(1)
        let (appStart, destination) = configuredAppStart(processStart: processStart)

        appStart.track(
            initialLifecycle: AppStartLifecycleSnapshot(
                launchOrigin: .foreground,
                didFinishLaunching: processStart.addingTimeInterval(0.1),
                willEnterForeground: nil,
                didBecomeActive: firstActive
            )
        )
        appStart.process(event: .willResignActive)
        appStart.process(event: .didBecomeActive(firstActive.addingTimeInterval(1)))

        XCTAssertEqual(destination.storedAppStarts.count, 1)
        XCTAssertEqual(destination.storedAppStart?.type, .cold)
    }
}
