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

internal import CiscoSwizzling
import Foundation
import UIKit
import XCTest

@testable import SplunkNavigation

final class NavigationTabControllerTransitionsTests: XCTestCase {

    // MARK: - Tab controller transitions

    @MainActor
    func testTabSelectionChange_UpdatesScreenName() async {
        let (module, provider) = makeModule(autoTrackingEnabled: true)
        module.startDetection()

        let firstController = FirstTabViewController()
        let secondController = SecondTabViewController()
        let tabBarController = UITabBarController()
        tabBarController.viewControllers = [firstController, secondController]
        tabBarController.selectedIndex = 0

        tabBarController.selectedIndex = 1
        await provider.emit(
            name: Notification.Name(rawValue: "UITabBarSelectionDidChangeNotification"),
            object: tabBarController.tabBar
        )

        await waitUntil {
            let screenName = await module.model.screenName
            return screenName.contains("SecondTabViewController")
        }
    }

    @MainActor
    func testTabSelectionChange_WithNavigationControllerTab_UsesVisibleController() async {
        let (module, provider) = makeModule(autoTrackingEnabled: true)
        module.startDetection()

        let firstController = FirstTabViewController()
        let secondRootController = SecondTabRootViewController()
        let firstNavigationController = UINavigationController(
            rootViewController: firstController
        )
        let secondNavigationController = UINavigationController(
            rootViewController: secondRootController
        )

        let tabBarController = UITabBarController()
        tabBarController.viewControllers = [
            firstNavigationController,
            secondNavigationController
        ]
        tabBarController.selectedIndex = 0

        tabBarController.selectedIndex = 1
        await provider.emit(
            name: Notification.Name(rawValue: "UITabBarSelectionDidChangeNotification"),
            object: tabBarController.tabBar
        )

        await waitUntil {
            let screenName = await module.model.screenName
            return screenName.contains("SecondTabRootViewController")
        }
    }


    // MARK: - Precedence

    @MainActor
    func testTabSelection_AutoDetectedNavigation_ReplacesManualScreenName_WhenAutoEnabled() async {
        let (module, provider) = makeModule(autoTrackingEnabled: true)
        module.startDetection()

        module.track(screen: "Manual Screen")
        await waitUntil {
            await module.model.screenName == "Manual Screen"
        }

        let firstController = FirstTabViewController()
        let secondController = SecondTabViewController()
        let tabBarController = UITabBarController()
        tabBarController.viewControllers = [firstController, secondController]

        tabBarController.selectedIndex = 1
        await provider.emit(
            name: Notification.Name(rawValue: "UITabBarSelectionDidChangeNotification"),
            object: tabBarController.tabBar
        )

        await waitUntil {
            let screenName = await module.model.screenName
            return screenName.contains("SecondTabViewController")
        }

        let isManualScreenName = await module.model.isManualScreenName
        XCTAssertFalse(isManualScreenName)
    }

    @MainActor
    func testTabSelection_AutoDetectedNavigation_DoesNotReplaceManualScreenName_WhenAutoDisabled() async {
        let (module, provider) = makeModule(autoTrackingEnabled: false)
        module.startDetection()

        module.track(screen: "Manual Screen")
        await waitUntil {
            await module.model.screenName == "Manual Screen"
        }

        let firstController = FirstTabViewController()
        let secondController = SecondTabViewController()
        let tabBarController = UITabBarController()
        tabBarController.viewControllers = [firstController, secondController]

        tabBarController.selectedIndex = 1
        await provider.emit(
            name: Notification.Name(rawValue: "UITabBarSelectionDidChangeNotification"),
            object: tabBarController.tabBar
        )

        try? await Task.sleep(nanoseconds: 50_000_000)

        let screenName = await module.model.screenName
        let isManualScreenName = await module.model.isManualScreenName

        XCTAssertEqual(screenName, "Manual Screen")
        XCTAssertTrue(isManualScreenName)
    }


    // MARK: - Helpers

    @MainActor
    private func makeModule(
        autoTrackingEnabled: Bool
    ) -> (Navigation, MockTabNotificationEventsProvider) {
        let provider = MockTabNotificationEventsProvider()
        let module = Navigation(
            navigationEventStreamProvider: EmptyTabNavigationEventStreamProvider(),
            notificationEventsProvider: provider
        )

        module.preferences.enableAutomatedTracking = autoTrackingEnabled
        return (module, provider)
    }

    private func waitUntil(
        timeoutNanoseconds: UInt64 = 1_000_000_000,
        predicate: @escaping @Sendable () async -> Bool
    ) async {
        let intervalNanoseconds: UInt64 = 10_000_000
        let attempts = Int(timeoutNanoseconds / intervalNanoseconds)

        for _ in 0 ..< attempts {
            if await predicate() {
                return
            }

            try? await Task.sleep(nanoseconds: intervalNanoseconds)
        }

        XCTFail("Timed out waiting for condition")
    }
}

private struct EmptyTabNavigationEventStreamProvider: NavigationEventStreamProviding {
    func navigationStream() async throws -> AsyncStream<any NavigationActionEvent> {
        await Task.yield()
        return AsyncStream { _ in }
    }
}

private actor TabNotificationContinuationsStore {
    private var continuations: [Notification.Name: AsyncStream<Notification>.Continuation] = [:]

    func set(
        continuation: AsyncStream<Notification>.Continuation,
        for name: Notification.Name
    ) {
        continuations[name] = continuation
    }

    func emit(_ notification: Notification, for name: Notification.Name) {
        continuations[name]?.yield(notification)
    }
}

private final class MockTabNotificationEventsProvider: NotificationEventsProviding {
    private let store = TabNotificationContinuationsStore()

    func notifications(for name: Notification.Name) -> AsyncStream<Notification> {
        AsyncStream { continuation in
            Task {
                await store.set(continuation: continuation, for: name)
            }
        }
    }

    func emit(name: Notification.Name, object: AnyObject?) async {
        let notification = Notification(
            name: name,
            object: object
        )

        await store.emit(notification, for: name)
    }
}

private final class FirstTabViewController: UIViewController {}
private final class SecondTabViewController: UIViewController {}
private final class SecondTabRootViewController: UIViewController {}
