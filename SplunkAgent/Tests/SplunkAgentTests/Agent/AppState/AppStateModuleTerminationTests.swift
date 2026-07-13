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

import Foundation
import XCTest

@testable import SplunkAppState
@testable import SplunkCommon

#if os(iOS) || os(tvOS) || os(visionOS)
    final class AppStateModuleTerminationTests: XCTestCase {

        // MARK: - Tests

        func testWillTerminatePostsProcessedNotificationAfterSendingTerminate() {
            let destination = AppStateTerminationTestDestination()
            let module = AppStateModule()
            module.sharedState = nil
            module.destination = destination
            module.setupNotifications()

            var terminateWasSentBeforeNotification = false
            let token = NotificationCenter.default.addObserver(
                forName: .splunkAppStateTerminateProcessed,
                object: nil,
                queue: nil
            ) { _ in
                terminateWasSentBeforeNotification = destination.states.last == .terminate
            }
            defer {
                NotificationCenter.default.removeObserver(token)
                module.removeNotifications()
            }

            NotificationCenter.default.post(name: UIApplication.willTerminateNotification, object: nil)

            XCTAssertEqual(destination.states.last, .terminate)
            XCTAssertTrue(terminateWasSentBeforeNotification)
        }
    }


    // MARK: - Helpers

    private final class AppStateTerminationTestDestination: AppStateDestination {
        private(set) var states: [AppStateType] = []

        func send(appState: AppStateType, time _: Date, sharedState _: AgentSharedState?) {
            states.append(appState)
        }
    }
#endif
