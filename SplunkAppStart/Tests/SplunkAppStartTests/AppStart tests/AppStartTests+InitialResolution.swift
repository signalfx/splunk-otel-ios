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
    func testNativeResolutionWaitsForRecorderHandoff() throws {
        let destination = DebugDestination()
        let now = Date()

        let appStart = AppStart()
        appStart.processStartTimestamp = now.addingTimeInterval(-2.0)
        appStart.destination = destination
        appStart.startDetection()
        defer { appStart.stopDetection() }
        appStart.deferInitialLifecycleResolution()

        NotificationCenter.default.post(name: UIApplication.didFinishLaunchingNotification, object: nil)
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        drainMainQueue()

        try checkNotDeterminedType(in: destination)
        XCTAssertEqual(appStart.initialAppStartState, .pending)

        appStart.consume(
            coreLifecycle: nil,
            snapshot: AppStartLifecycleSnapshot(
                launchOrigin: .foreground,
                launchOriginConfidence: .observed,
                didFinishLaunching: now.addingTimeInterval(-1.5),
                willEnterForeground: now.addingTimeInterval(-1.0),
                didBecomeActive: now
            )
        )
        appStart.resumeInitialLifecycleResolution()

        try checkDeterminedType(.cold, in: destination)
    }
}
