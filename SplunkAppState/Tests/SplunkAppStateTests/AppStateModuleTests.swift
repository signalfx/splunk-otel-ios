//
/*
Copyright 2025 Splunk Inc.

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

@testable import SplunkAppState

final class AppStateModuleTests: XCTestCase {

    // MARK: - Private properties

    #if os(iOS) || os(tvOS) || os(visionOS)
        private let expectedObserverCount = 5
    #else
        private let expectedObserverCount = 0
    #endif


    // MARK: - Test functions

    func testSetupNotificationsAddsExpectedNumberOfObservers() {
        let module = AppStateModule()
        module.setupNotifications()
        XCTAssertEqual(module.notificationObservers.count, expectedObserverCount)
    }

    func testSetupNotificationsIsIdempotent() {
        let module = AppStateModule()
        module.setupNotifications()
        module.setupNotifications()
        XCTAssertEqual(module.notificationObservers.count, expectedObserverCount)
    }

    func testRemoveNotificationsClearsObservers() {
        let module = AppStateModule()
        module.setupNotifications()
        module.removeNotifications()
        XCTAssertEqual(module.notificationObservers.count, 0)
    }

    func testStartStopDetectionMirrorSetupRemove() {
        let module = AppStateModule()
        module.startDetection()
        XCTAssertEqual(module.notificationObservers.count, expectedObserverCount)
        module.stopDetection()
        XCTAssertEqual(module.notificationObservers.count, 0)
    }

    func testPostingNotificationsDoesNotCrash() {
        let module = AppStateModule()
        module.setupNotifications()

        #if os(iOS) || os(tvOS) || os(visionOS)
            NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
            NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
            NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
            NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
            NotificationCenter.default.post(name: UIApplication.willTerminateNotification, object: nil)
        #endif

        XCTAssertEqual(module.notificationObservers.count, expectedObserverCount)
    }

    func testDeinitRemovesObservers() {
        weak var weakModule: AppStateModule?
        autoreleasepool {
            let module = AppStateModule()
            module.setupNotifications()
            XCTAssertEqual(module.notificationObservers.count, expectedObserverCount)
            weakModule = module
        }
        XCTAssertNil(weakModule)
    }


    #if os(iOS) || os(tvOS) || os(visionOS)

        func testDidBecomeActiveSendsActive() {
            let mock = MockDestination()
            let module = makeModule(with: mock)
            NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
            expectEventCount(mock, count: 1)
            XCTAssertEqual(mock.events.last?.state, .active)
            module.removeNotifications()
        }

        func testDidEnterBackgroundSendsBackground() {
            let mock = MockDestination()
            let module = makeModule(with: mock)
            NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
            expectEventCount(mock, count: 1)
            XCTAssertEqual(mock.events.last?.state, .background)
            module.removeNotifications()
        }

        func testWillEnterForegroundSendsForeground() {
            let mock = MockDestination()
            let module = makeModule(with: mock)
            NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
            expectEventCount(mock, count: 1)
            XCTAssertEqual(mock.events.last?.state, .foreground)
            module.removeNotifications()
        }

        func testWillResignActiveSendsInactive() {
            let mock = MockDestination()
            let module = makeModule(with: mock)
            NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
            expectEventCount(mock, count: 1)
            XCTAssertEqual(mock.events.last?.state, .inactive)
            module.removeNotifications()
        }

        func testWillTerminateSendsTerminate() {
            let mock = MockDestination()
            let module = makeModule(with: mock)
            NotificationCenter.default.post(name: UIApplication.willTerminateNotification, object: nil)
            expectEventCount(mock, count: 1)
            XCTAssertEqual(mock.events.last?.state, .terminate)
            module.removeNotifications()
        }

        func testSequenceOrderIsPreserved() {
            let mock = MockDestination()
            let module = makeModule(with: mock)
            NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
            NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
            NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
            NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
            expectEventCount(mock, count: 4)
            XCTAssertEqual(mock.events.map(\.state), [.inactive, .background, .foreground, .active])
            module.removeNotifications()
        }

        func testNoEventsAfterStopDetection() {
            let mock = MockDestination()
            let module = makeModule(with: mock)
            module.stopDetection()
            mock.reset()
            NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
            XCTAssertTrue(mock.events.isEmpty)
        }

    #endif


    // MARK: - Private helpers

    private func makeModule(with mock: MockDestination) -> AppStateModule {
        let module = AppStateModule()
        module.sharedState = nil
        module.destination = mock
        module.setupNotifications()

        return module
    }

    private func expectEventCount(_ mock: MockDestination, count: Int, timeout: TimeInterval = 1.0) {
        let exp = expectation(description: "events \(count)")
        mock.onSend = { [weak mock] in
            if (mock?.events.count ?? 0) >= count {
                exp.fulfill()
            }
        }
        if mock.events.count >= count {
            exp.fulfill()
        }
        wait(for: [exp], timeout: timeout)
        mock.onSend = nil
    }
}
