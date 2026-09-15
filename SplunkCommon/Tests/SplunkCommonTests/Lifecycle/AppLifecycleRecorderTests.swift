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

import UIKit
import XCTest

@_spi(SplunkInternal) @testable import SplunkCommon

final class AppLifecycleRecorderTests: XCTestCase {

    func testInitialLifecycleFieldsUseFirstEventWins() {
        let notificationCenter = NotificationCenter()
        let recorder = AppLifecycleRecorder(notificationCenter: notificationCenter)

        notificationCenter.post(name: UIApplication.didFinishLaunchingNotification, object: nil)
        notificationCenter.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        notificationCenter.post(name: UIApplication.didBecomeActiveNotification, object: nil)

        let firstSnapshot = recorder.snapshot()

        notificationCenter.post(name: UIApplication.didFinishLaunchingNotification, object: nil)
        notificationCenter.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        notificationCenter.post(name: UIApplication.didBecomeActiveNotification, object: nil)

        let secondSnapshot = recorder.snapshot()

        XCTAssertEqual(secondSnapshot.launchOrigin, firstSnapshot.launchOrigin)
        XCTAssertEqual(secondSnapshot.didFinishLaunching, firstSnapshot.didFinishLaunching)
        XCTAssertEqual(secondSnapshot.willEnterForeground, firstSnapshot.willEnterForeground)
        XCTAssertEqual(secondSnapshot.didBecomeActive, firstSnapshot.didBecomeActive)
    }

    func testUnknownOriginIsNotConvertedToForeground() {
        let notificationCenter = NotificationCenter()
        let recorder = AppLifecycleRecorder(notificationCenter: notificationCenter)

        notificationCenter.post(name: UIApplication.didBecomeActiveNotification, object: nil)

        XCTAssertEqual(recorder.snapshot().launchOrigin, .unknown)
    }

    func testForegroundLaunchWithoutForegroundBoundaryIsDetectedFromLifecycleSequence() {
        let notificationCenter = NotificationCenter()
        let recorder = AppLifecycleRecorder(notificationCenter: notificationCenter)

        notificationCenter.post(name: UIApplication.didFinishLaunchingNotification, object: nil)
        notificationCenter.post(name: UIApplication.didBecomeActiveNotification, object: nil)

        XCTAssertEqual(recorder.snapshot().launchOrigin, .foreground)
    }

    func testSubscribersReceiveLifecycleEventTimestamp() {
        let notificationCenter = NotificationCenter()
        let recorder = AppLifecycleRecorder(notificationCenter: notificationCenter)
        let eventReceived = expectation(description: "didBecomeActive event received")

        recorder.addObserver { update in
            guard case let .didBecomeActive(timestamp) = update.event else {
                return
            }

            XCTAssertEqual(update.snapshot.didBecomeActive, timestamp)
            eventReceived.fulfill()
        }

        notificationCenter.post(name: UIApplication.didBecomeActiveNotification, object: nil)

        wait(for: [eventReceived], timeout: 1.0)
    }
}
