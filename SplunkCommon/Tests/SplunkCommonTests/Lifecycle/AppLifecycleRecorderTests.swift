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
        XCTAssertEqual(secondSnapshot.launchOriginConfidence, .observed)
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
        XCTAssertEqual(recorder.snapshot().launchOriginConfidence, .observed)
    }

    func testForegroundLaunchWithForegroundBoundaryIsNotMarkedAsBackground() {
        let notificationCenter = NotificationCenter()
        let recorder = AppLifecycleRecorder(notificationCenter: notificationCenter)

        notificationCenter.post(name: UIApplication.didFinishLaunchingNotification, object: nil)
        notificationCenter.post(name: UIApplication.willEnterForegroundNotification, object: nil)

        XCTAssertEqual(recorder.snapshot().launchOrigin, .foreground)
    }

    func testDidFinishLaunchingRetainsLaunchOptionKeys() {
        let notificationCenter = NotificationCenter()
        let recorder = AppLifecycleRecorder(notificationCenter: notificationCenter)
        let urlKey = UIApplication.LaunchOptionsKey(rawValue: "test.url")
        let metadataKey = UIApplication.LaunchOptionsKey(rawValue: "test.metadata")
        let launchOptions: [UIApplication.LaunchOptionsKey: Any] = [
            urlKey: URL(string: "https://example.com") as Any,
            metadataKey: "test"
        ]

        notificationCenter.post(
            name: UIApplication.didFinishLaunchingNotification,
            object: nil,
            userInfo: launchOptions
        )

        XCTAssertEqual(
            recorder.snapshot().events.first?.launchOptionKeys,
            [metadataKey.rawValue, urlKey.rawValue].sorted()
        )
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

    func testSnapshotRetainsBoundedOrderedLifecycleHistory() {
        let notificationCenter = NotificationCenter()
        let recorder = AppLifecycleRecorder(notificationCenter: notificationCenter)

        notificationCenter.post(name: UIApplication.didFinishLaunchingNotification, object: nil)
        notificationCenter.post(name: UIApplication.willResignActiveNotification, object: nil)
        notificationCenter.post(name: UIApplication.didEnterBackgroundNotification, object: nil)

        let events = recorder.snapshot().events

        XCTAssertEqual(
            events.map(\.kind),
            [.didFinishLaunching, .willResignActive, .didEnterBackground]
        )
        XCTAssertEqual(events.map(\.sequence), [1, 2, 3])
        XCTAssertEqual(events.map(\.source), [.notification, .notification, .notification])
    }

    func testLateObserverReceivesPreviouslyRecordedHistory() {
        let notificationCenter = NotificationCenter()
        let recorder = AppLifecycleRecorder(notificationCenter: notificationCenter)
        notificationCenter.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        notificationCenter.post(name: UIApplication.didBecomeActiveNotification, object: nil)

        let observerReceived = expectation(description: "history replay received")
        recorder.addObserver { update in
            guard update.event == nil else {
                return
            }

            XCTAssertEqual(
                update.snapshot.events.map(\.kind),
                [.willEnterForeground, .didBecomeActive]
            )
            observerReceived.fulfill()
        }

        wait(for: [observerReceived], timeout: 1.0)
    }
}
