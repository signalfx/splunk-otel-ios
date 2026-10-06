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

import Dispatch
import XCTest

@_spi(SplunkInternal) @testable import SplunkAppStart

extension AppStartTests {

    // MARK: - Notification observation

    func testModuleInstallationDefersObservationUntilAgentWiring() {
        let appStart = AppStart()

        appStart.install(with: nil, remoteConfiguration: nil)

        XCTAssertNil(appStart.notificationTokens)

        appStart.startDetection()

        XCTAssertNotNil(appStart.notificationTokens)
    }

    func testNotificationObserverEmitsColdStart() throws {
        let processStart = Date().addingTimeInterval(-0.1)
        let destination = DebugDestination()
        let appStart = AppStart()
        appStart.processStartTimestamp = processStart
        appStart.destination = destination
        appStart.track(
            initialLifecycle: AppStartLifecycleSnapshot(
                launchOrigin: .foreground,
                didFinishLaunching: processStart.addingTimeInterval(0.1),
                willEnterForeground: nil,
                didBecomeActive: nil
            )
        )
        appStart.startDetection()

        NotificationCenter.default.post(
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        try checkDeterminedType(.cold, in: destination)
    }

    func testNotificationObserverCompletesPartialHybridWarmStart() throws {
        let processStart = Date().addingTimeInterval(-2)
        let foreground = Date().addingTimeInterval(-1)
        let destination = DebugDestination()
        let appStart = AppStart()
        appStart.processStartTimestamp = processStart
        appStart.destination = destination
        appStart.track(
            initialLifecycle: AppStartLifecycleSnapshot(
                launchOrigin: .background,
                didFinishLaunching: processStart.addingTimeInterval(0.1),
                willEnterForeground: foreground,
                didBecomeActive: nil
            )
        )
        appStart.startDetection()

        NotificationCenter.default.post(
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        try checkDeterminedType(.warm, in: destination)
        let span = try XCTUnwrap(destination.storedAppStart)
        XCTAssertEqual(span.start, foreground)
    }

    func testStopRemovesNotificationObserver() throws {
        let destination = DebugDestination()
        let appStart = AppStart()
        appStart.destination = destination
        appStart.startDetection()
        appStart.stopDetection()

        simulateColdStartNotifications()

        try checkNotDeterminedType(in: destination)
    }

    func testConcurrentStartAndStopLeavesNoActiveObserver() {
        let processStart = Date(timeIntervalSinceReferenceDate: 500)
        let (appStart, destination) = configuredAppStart(processStart: processStart)

        appStart.track(
            initialLifecycle: AppStartLifecycleSnapshot(
                launchOrigin: .foreground,
                didFinishLaunching: processStart.addingTimeInterval(0.1),
                willEnterForeground: nil,
                didBecomeActive: processStart.addingTimeInterval(1)
            )
        )

        DispatchQueue.concurrentPerform(iterations: 100) { iteration in
            if iteration.isMultiple(of: 2) {
                appStart.startDetection()
            }
            else {
                appStart.stopDetection()
            }
        }
        appStart.stopDetection()

        NotificationCenter.default.post(
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.post(
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        NotificationCenter.default.post(
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        XCTAssertNil(appStart.notificationTokens)
        XCTAssertEqual(destination.storedAppStarts.count, 1)
    }

    func testRestartDropsObservationGapAndEmitsNextCompleteHotStart() throws {
        let destination = DebugDestination()
        let appStart = AppStart()
        let processStart = Date().addingTimeInterval(-1)
        appStart.processStartTimestamp = processStart
        appStart.destination = destination

        appStart.track(
            initialLifecycle: AppStartLifecycleSnapshot(
                launchOrigin: .foreground,
                didFinishLaunching: processStart.addingTimeInterval(0.1),
                willEnterForeground: nil,
                didBecomeActive: processStart.addingTimeInterval(0.5)
            )
        )

        appStart.startDetection()
        appStart.stopDetection()
        appStart.startDetection()

        NotificationCenter.default.post(
            name: UIApplication.didEnterBackgroundNotification,
            object: UIApplication.shared
        )
        NotificationCenter.default.post(
            name: UIApplication.willEnterForegroundNotification,
            object: UIApplication.shared
        )
        NotificationCenter.default.post(
            name: UIApplication.didBecomeActiveNotification,
            object: UIApplication.shared
        )

        XCTAssertEqual(destination.storedAppStarts.count, 2)
        let hot = try XCTUnwrap(destination.storedAppStarts.last)
        XCTAssertEqual(hot.type, .hot)
    }

    func testOffMainLaunchNotificationIsTreatedAsUnknown() {
        let processStart = Date().addingTimeInterval(-1)
        let (appStart, destination) = configuredAppStart(processStart: processStart)
        let notificationPosted = expectation(description: "Launch notification posted")
        appStart.startDetection()

        DispatchQueue.global()
            .async {
                NotificationCenter.default.post(
                    name: UIApplication.didFinishLaunchingNotification,
                    object: nil
                )
                notificationPosted.fulfill()
            }

        wait(for: [notificationPosted], timeout: 1)
        appStart.process(event: .didBecomeActive(Date()))

        XCTAssertNil(destination.storedAppStart)
        XCTAssertEqual(appStart.suppressionReason, .unknownLaunchOrigin)
    }
}
