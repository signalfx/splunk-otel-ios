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
    func testTruncatedSnapshotKeepsPreservedInitialActivation() throws {
        let destination = DebugDestination()
        let notificationCenter = NotificationCenter()
        let recorder = AppLifecycleRecorder(notificationCenter: notificationCenter)

        notificationCenter.post(name: UIApplication.didFinishLaunchingNotification, object: nil)
        notificationCenter.post(name: UIApplication.didBecomeActiveNotification, object: nil)

        for _ in 0 ..< 33 {
            notificationCenter.post(name: UIApplication.willResignActiveNotification, object: nil)
            notificationCenter.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
            notificationCenter.post(name: UIApplication.willEnterForegroundNotification, object: nil)
            notificationCenter.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        }

        let snapshot = recorder.snapshot()
        XCTAssertGreaterThan(snapshot.events.first?.sequence ?? 0, 1)

        let appStart = AppStart()
        appStart.destination = destination
        appStart.processStartTimestamp = try XCTUnwrap(snapshot.didFinishLaunching).addingTimeInterval(-1.0)

        appStart.consume(
            coreLifecycle: nil,
            snapshot: AppStartLifecycleSnapshot(
                launchOrigin: .foreground,
                launchOriginConfidence: .observed,
                didFinishLaunching: snapshot.didFinishLaunching,
                willEnterForeground: snapshot.willEnterForeground,
                didBecomeActive: snapshot.didBecomeActive,
                events: snapshot.events
            )
        )

        try checkDeterminedType(.cold, in: destination)
        XCTAssertEqual(destination.storedAppStart?.end, snapshot.didBecomeActive)
    }
}
