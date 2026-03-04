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
import UIKit

extension Navigation {

    // MARK: - Types

    private struct TabSelectionSnapshot {
        let controllerIdentifier: ObjectIdentifier
        let controllerTypeName: String
    }

    // MARK: - Legacy tab controller handling

    func processTabBarSelectionDidChange(notification: Notification) async {
        guard
            await shouldProcessEvent(),
            state.isAutomatedTrackingEnabled,
            let snapshot = await tabSelectionSnapshot(from: notification)
        else {
            return
        }

        let controllerIdentifier = snapshot.controllerIdentifier
        let typeName = snapshot.controllerTypeName
        let screenName = sanitize(typeName: typeName)
        let lastScreenName = await model.screenName

        if await model.navigation(for: controllerIdentifier) == nil {
            let fallbackNavigation = NavigationPair(
                type: .show,
                start: Date(),
                typeName: typeName,
                screenName: screenName
            )
            await model.update(
                navigation: fallbackNavigation,
                for: controllerIdentifier
            )
        }

        let start = await model.navigation(for: controllerIdentifier)?.start
            ?? Date()

        await model.update(screenName: screenName)
        await model.update(isManualScreenName: false)

        if screenName != lastScreenName {
            continuation.yield(screenName)
            send(
                screenName: screenName,
                lastScreenName: lastScreenName,
                start: start
            )
        }

        let event = AutomatedNavigationEvent(
            timestamp: Date(),
            type: .viewDidAppear,
            controllerTypeName: screenName,
            controllerIdentifier: controllerIdentifier
        )

        await processNavigationEnd(event: event)
    }


    // MARK: - Private methods

    @MainActor
    private func tabSelectionSnapshot(
        from notification: Notification
    ) -> TabSelectionSnapshot? {
        guard
            let tabBarController = targetTabBarController(from: notification),
            let selectedController = selectedViewController(from: tabBarController)
        else {
            return nil
        }

        return TabSelectionSnapshot(
            controllerIdentifier: ObjectIdentifier(selectedController),
            controllerTypeName: preferredControllerName(for: selectedController)
        )
    }

    @MainActor
    private func targetTabBarController(
        from notification: Notification
    ) -> UITabBarController? {
        if let tabBarController = notification.object as? UITabBarController {
            return tabBarController
        }

        guard let tabBar = notification.object as? UITabBar else {
            return nil
        }

        if let tabBarController = tabBar.delegate as? UITabBarController {
            return tabBarController
        }

        var responder: UIResponder? = tabBar
        while let nextResponder = responder?.next {
            if let tabBarController = nextResponder as? UITabBarController {
                return tabBarController
            }

            responder = nextResponder
        }

        return nil
    }

    @MainActor
    private func selectedViewController(
        from tabBarController: UITabBarController
    ) -> UIViewController? {
        guard let selectedController = tabBarController.selectedViewController
        else {
            return nil
        }

        if let navigationController =
            selectedController as? UINavigationController
        {
            return navigationController.visibleViewController
                ?? navigationController
        }

        return selectedController
    }
}
