//
/*
Copyright 2024 Splunk Inc.

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

@testable import SplunkAgent
import XCTest

class AppStateManagerTests: XCTestCase {

    func testRemoveOldEvents() {
        let storage = UserDefaultsStorageTestBuilder.buildCleanStorage(named: "testRemoveOldEvents")

        let oldDate = Date().addingTimeInterval(-3_000_000)
        let oldEvent = AppStateEvent(timestamp: oldDate, state: .active)
        try? storage.update([oldEvent], forKey: "appStateEvents")

        let appStateModel = AppStateModel(storage: storage)
        let appStateManager = AppStateManager(appStateModel: appStateModel)

        for _ in 0 ... 120 {
            appStateModel.saveEvent(.inactive)
        }

        let events: [AppStateEvent] = (try? storage.read(forKey: "appStateEvents")) ?? []

        XCTAssertFalse(events.contains(where: { $0.timestamp < oldDate }))
        XCTAssertEqual(events.count, 100)
    }

    func testGetAppStateForDate() {
        let storage = UserDefaultsStorageTestBuilder.buildCleanStorage(named: "testGetAppStateForDate")
        let testDate = Date()
        let testEvents = [
            AppStateEvent(timestamp: testDate.addingTimeInterval(-9), state: .active),
            AppStateEvent(timestamp: testDate.addingTimeInterval(-8), state: .background),
            AppStateEvent(timestamp: testDate.addingTimeInterval(-7), state: .inactive),
            AppStateEvent(timestamp: testDate, state: .foreground),
            AppStateEvent(timestamp: testDate.addingTimeInterval(7), state: .terminate),
            AppStateEvent(timestamp: testDate.addingTimeInterval(8), state: .active),
            AppStateEvent(timestamp: testDate.addingTimeInterval(9), state: .background)
        ]

        try? storage.update(testEvents, forKey: "appStateEvents")

        let appStateModel = AppStateModel(storage: storage)
        let appStateManager = AppStateManager(appStateModel: appStateModel)
        let retrievedState = appStateManager.appState(for: testDate.addingTimeInterval(2))
        XCTAssertEqual(retrievedState, .foreground)
    }

    func testNotificationsHandle() {
        let storage = UserDefaultsStorageTestBuilder.buildCleanStorage(named: "testNotificationsHandle")
        try? storage.delete(forKey: "appStateEvents")

        let appStateModel = AppStateModel(storage: storage)
        let appStateManager = AppStateManager(appStateModel: appStateModel)

        let notifications = [
            UIApplication.didBecomeActiveNotification,
            UIApplication.didEnterBackgroundNotification,
            UIApplication.willEnterForegroundNotification,
            UIApplication.willResignActiveNotification,
            UIApplication.willTerminateNotification
        ]

        for notification in notifications {
            sendSimulatedNotification(notification)
            simulateMainThreadWait(duration: 1)
        }

        simulateMainThreadWait(duration: 2)

        let events: [AppStateEvent] = (try? storage.read(forKey: "appStateEvents")) ?? []
        XCTAssertEqual(events.count, 5)

        let retrievedState = appStateManager.appState(for: Date())
        XCTAssertEqual(retrievedState, .terminate)
    }
}
