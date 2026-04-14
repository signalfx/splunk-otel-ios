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

import CiscoSwizzling
import Foundation

extension Navigation {

    // MARK: - Navigation-controller transitions

    func processNavigationControllerWillShow(
        event: any NavigationActionEvent
    ) async {
        guard let navigationControllerIdentifier = event.navigationControllerIdentifier else {
            return
        }

        let typeName = event.controllerTypeName
        let screenName = sanitize(typeName: typeName)
        let controllerIdentifier = event.controllerIdentifier
        let lastScreenName = await model.screenName

        let navigation = NavigationPair(
            type: .show,
            start: event.timestamp,
            typeName: typeName,
            screenName: screenName
        )

        await model.update(navigation: navigation, for: controllerIdentifier)
        await model.update(
            pendingNavigationTarget: controllerIdentifier,
            for: navigationControllerIdentifier
        )
        await model.addManagedNavigationControllerTarget(controllerIdentifier)
        await model.update(screenName: screenName)

        if screenName != lastScreenName {
            continuation.yield(screenName)
            send(
                screenName: screenName,
                lastScreenName: lastScreenName,
                start: event.timestamp
            )
        }
    }

    func processNavigationControllerDidShow(
        event: any NavigationActionEvent
    ) async {
        guard let navigationControllerIdentifier = event.navigationControllerIdentifier else {
            return
        }

        let visibleControllerIdentifier = event.controllerIdentifier

        if await handleCancelledTransitionIfNeeded(
            navigationControllerIdentifier: navigationControllerIdentifier,
            visibleControllerIdentifier: visibleControllerIdentifier,
            visibleControllerTypeName: event.controllerTypeName,
            timestamp: event.timestamp
        ) {
            await model.removeManagedNavigationControllerTarget(visibleControllerIdentifier)
            return
        }

        await completeNavigationControllerTransition(event: event)
        await model.removePendingNavigationTarget(
            for: navigationControllerIdentifier
        )
        await model.removeManagedNavigationControllerTarget(visibleControllerIdentifier)
    }


    // MARK: - Private methods

    private func handleCancelledTransitionIfNeeded(
        navigationControllerIdentifier: ObjectIdentifier,
        visibleControllerIdentifier: ObjectIdentifier,
        visibleControllerTypeName: String,
        timestamp: Date
    ) async -> Bool {
        guard
            let pendingTargetIdentifier = await model.pendingNavigationTarget(
                for: navigationControllerIdentifier
            ),
            pendingTargetIdentifier != visibleControllerIdentifier
        else {
            return false
        }

        // Interactive pop cancellation keeps the current controller visible.
        // Drop the previously pending navigation transition.
        await model.removeNavigation(for: pendingTargetIdentifier)
        await model.removePendingNavigationTarget(
            for: navigationControllerIdentifier
        )
        await model.removeManagedNavigationControllerTarget(pendingTargetIdentifier)
        await updateCurrentScreen(
            typeName: visibleControllerTypeName,
            start: timestamp
        )
        return true
    }

    private func completeNavigationControllerTransition(
        event: any NavigationActionEvent
    ) async {
        let typeName = event.controllerTypeName
        let screenName = sanitize(typeName: typeName)
        let lastScreenName = await model.screenName
        let visibleControllerIdentifier = event.controllerIdentifier

        if await model.navigation(for: visibleControllerIdentifier) == nil {
            let fallbackNavigation = NavigationPair(
                type: .show,
                start: event.timestamp,
                typeName: typeName,
                screenName: screenName
            )
            await model.update(
                navigation: fallbackNavigation,
                for: visibleControllerIdentifier
            )
        }

        let start =
            await model.navigation(for: visibleControllerIdentifier)?.start
            ?? event.timestamp

        await updateCurrentScreen(
            screenName: screenName,
            lastScreenName: lastScreenName,
            start: start
        )

        let endEvent = AutomatedNavigationEvent(
            timestamp: event.timestamp,
            type: .viewDidAppear,
            controllerTypeName: typeName,
            controllerIdentifier: visibleControllerIdentifier
        )

        await processNavigationEnd(event: endEvent)
    }

    private func updateCurrentScreen(
        typeName: String,
        start: Date
    ) async {
        let screenName = sanitize(typeName: typeName)
        let lastScreenName = await model.screenName

        await updateCurrentScreen(
            screenName: screenName,
            lastScreenName: lastScreenName,
            start: start
        )
    }

    private func updateCurrentScreen(
        screenName: String,
        lastScreenName: String,
        start: Date
    ) async {
        await model.update(screenName: screenName)

        if screenName != lastScreenName {
            continuation.yield(screenName)
            send(
                screenName: screenName,
                lastScreenName: lastScreenName,
                start: start
            )
        }
    }
}
