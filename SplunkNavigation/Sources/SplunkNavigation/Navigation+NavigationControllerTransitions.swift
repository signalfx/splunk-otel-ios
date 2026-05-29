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

    func processNavigationControllerWillShow(event: any NavigationActionEvent) async {
        guard let navigationControllerIdentifier = event.navigationControllerIdentifier else {
            return
        }

        let typeName = event.controllerTypeName
        let controllerIdentifier = event.controllerIdentifier

        let navigation = NavigationPair(
            type: .show,
            start: event.timestamp,
            screenName: sanitize(typeName: typeName)
        )

        await model.update(navigation: navigation, for: controllerIdentifier)

        await model.update(
            pendingNavigationTarget: controllerIdentifier,
            for: navigationControllerIdentifier
        )

        await model.addManagedNavigationControllerTarget(controllerIdentifier)
    }

    func processNavigationControllerDidShow(event: any NavigationActionEvent) async {
        guard let navigationControllerIdentifier = event.navigationControllerIdentifier else {
            return
        }

        let visibleControllerIdentifier = event.controllerIdentifier

        if await handleCancelledTransitionIfNeeded(
            navigationControllerIdentifier: navigationControllerIdentifier,
            visibleControllerIdentifier: visibleControllerIdentifier
        ) {
            return
        }

        await completeNavigationControllerTransition(event: event)

        await model.removePendingNavigationTarget(for: navigationControllerIdentifier)
        await model.removeManagedNavigationControllerTarget(visibleControllerIdentifier)
    }


    // MARK: - Private methods

    private func handleCancelledTransitionIfNeeded(
        navigationControllerIdentifier: ObjectIdentifier,
        visibleControllerIdentifier: ObjectIdentifier
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
        await model.removePendingNavigationTarget(for: navigationControllerIdentifier)
        await model.removeManagedNavigationControllerTarget(pendingTargetIdentifier)

        await model.removeManagedNavigationControllerTarget(visibleControllerIdentifier)
        return true
    }

    private func completeNavigationControllerTransition(event: any NavigationActionEvent) async {
        await commitNavigation(event: event, fallbackType: .show)
    }

    func updateCurrentScreen(
        screenName: String,
        start: Date,
        attributes: [String: Any]? = nil
    ) {
        // forceEmit: false — automated detection deduplicates repeated visits to the same screen.
        // Manual track(screen:) uses forceEmit: true because the caller explicitly requests a new span.
        let screenStateUpdate = updateCurrentScreenState(
            screenName: screenName,
            attributes: attributes,
            forceEmit: false
        )

        guard screenStateUpdate.shouldEmit else {
            return
        }

        publishScreenNameChange(screenName)
        send(
            screenName: screenName,
            lastScreenName: screenStateUpdate.previousName,
            start: start,
            attributes: attributes
        )
    }

    func updateCurrentScreen(
        state: NavigationScreenState,
        start: Date
    ) {
        let screenStateUpdate = updateCurrentScreenState(
            state,
            forceEmit: false
        )

        guard screenStateUpdate.shouldEmit else {
            return
        }

        publishScreenNameChange(state.name)
        send(
            screenName: state.name,
            lastScreenName: screenStateUpdate.previousName,
            start: start,
            attributes: state.attributes
        )
    }
}
