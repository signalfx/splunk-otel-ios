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
@_spi(SplunkInternal) @testable import SplunkCommon

extension AppStartTests {
    func testLongObservedHotStartIsNotSuppressedByInitialDurationGuard() throws {
        let destination = DebugDestination()
        let now = Date()
        let initialActivation = now.addingTimeInterval(-10.0)

        let appStart = AppStart()
        appStart.destination = destination
        appStart.processStartTimestamp = now.addingTimeInterval(-11.0)
        appStart.maxAppStartDuration = 5.0

        appStart.track(
            initialLifecycle: AppStartLifecycleSnapshot(
                launchOrigin: .foreground,
                launchOriginConfidence: .observed,
                didFinishLaunching: now.addingTimeInterval(-10.5),
                willEnterForeground: now.addingTimeInterval(-10.25),
                didBecomeActive: initialActivation
            )
        )

        appStart.processCoreLifecycleEvent(.willResignActive(now))
        appStart.processCoreLifecycleEvent(.willEnterForeground(now.addingTimeInterval(10.0)))
        appStart.processCoreLifecycleEvent(.didBecomeActive(now.addingTimeInterval(20.0)))

        let storedAppStart = try XCTUnwrap(destination.storedAppStart)
        XCTAssertEqual(storedAppStart.type, .hot)
        XCTAssertEqual(storedAppStart.start, now.addingTimeInterval(10.0))
        XCTAssertEqual(storedAppStart.end, now.addingTimeInterval(20.0))
    }
}
