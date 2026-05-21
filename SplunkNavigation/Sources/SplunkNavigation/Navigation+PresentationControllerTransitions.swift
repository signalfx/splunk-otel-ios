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

    // MARK: - Types

    private struct PresentationTransitionSnapshot {
        let controllerIdentifier: ObjectIdentifier
        let controllerTypeName: String
    }


    // MARK: - Presentation controller transitions

    func processPresentationEvent(event: any PresentationActionEvent) async {
        // Filter on the controller whose screen name will be set:
        // presented for presentations, presenting for dismissals.
        switch event.type {
        case .presentationWillBegin:
            await handlePresentationWillBegin(event)

        case .presentationDidEnd:
            await handlePresentationDidEnd(event)

        case .dismissalWillBegin:
            await handleDismissalWillBegin(event)

        case .dismissalDidEnd:
            await handleDismissalDidEnd(event)

        @unknown default:
            break
        }
    }


    // MARK: - Private methods

    private func handlePresentationWillBegin(_ event: any PresentationActionEvent) async {
        guard !Self.shouldIgnore(controllerTypeName: event.presentedControllerTypeName) else {
            return
        }

        await model.update(
            pendingPresentationRestoration: currentScreenState(),
            for: event.presentationControllerIdentifier
        )
        await updateTransitionStart(for: presentedSnapshot(from: event), timestamp: event.timestamp)
    }

    private func handlePresentationDidEnd(_ event: any PresentationActionEvent) async {
        guard !Self.shouldIgnore(controllerTypeName: event.presentedControllerTypeName) else {
            return
        }

        let completed = event.completed ?? true
        await finalizeTransition(
            for: presentedSnapshot(from: event),
            timestamp: event.timestamp,
            completed: completed
        )

        if !completed {
            await model.removePendingPresentationRestoration(for: event.presentationControllerIdentifier)
        }
    }

    private func handleDismissalWillBegin(_ event: any PresentationActionEvent) async {
        if isNavigationControllerPresenter(event.presentingControllerTypeName) {
            await updateRestorationTransitionStart(event: event)
            return
        }

        guard !Self.shouldIgnore(controllerTypeName: event.presentingControllerTypeName) else {
            return
        }

        await updateTransitionStart(for: presentingSnapshot(from: event), timestamp: event.timestamp)
    }

    private func handleDismissalDidEnd(_ event: any PresentationActionEvent) async {
        if isNavigationControllerPresenter(event.presentingControllerTypeName) {
            await finalizeRestorationTransition(event: event)
            return
        }

        guard !Self.shouldIgnore(controllerTypeName: event.presentingControllerTypeName) else {
            return
        }

        let completed = event.completed ?? true
        await finalizeTransition(
            for: presentingSnapshot(from: event),
            timestamp: event.timestamp,
            completed: completed
        )

        if completed {
            await model.removePendingPresentationRestoration(for: event.presentationControllerIdentifier)
        }
    }

    private func presentedSnapshot(from event: any PresentationActionEvent) -> PresentationTransitionSnapshot {
        PresentationTransitionSnapshot(
            controllerIdentifier: event.presentedControllerIdentifier,
            controllerTypeName: event.presentedControllerTypeName
        )
    }

    private func presentingSnapshot(from event: any PresentationActionEvent) -> PresentationTransitionSnapshot {
        PresentationTransitionSnapshot(
            controllerIdentifier: event.presentingControllerIdentifier,
            controllerTypeName: event.presentingControllerTypeName
        )
    }

    private func updateTransitionStart(for snapshot: PresentationTransitionSnapshot, timestamp: Date) async {
        let navigation = NavigationPair(
            type: .transition,
            start: timestamp,
            screenName: sanitize(typeName: snapshot.controllerTypeName)
        )

        await model.update(
            navigation: navigation,
            for: snapshot.controllerIdentifier
        )
    }

    private func finalizeTransition(
        for snapshot: PresentationTransitionSnapshot,
        timestamp: Date,
        completed: Bool
    ) async {
        guard completed else {
            await model.removeNavigation(for: snapshot.controllerIdentifier)
            return
        }

        let typeName = snapshot.controllerTypeName

        let event = AutomatedNavigationEvent(
            timestamp: timestamp,
            type: .didTransitionToTraitCollection,
            controllerTypeName: typeName,
            controllerIdentifier: snapshot.controllerIdentifier
        )

        await commitNavigation(event: event, fallbackType: .transition)
    }

    private func isNavigationControllerPresenter(_ typeName: String) -> Bool {
        typeName == "UINavigationController"
    }

    private func updateRestorationTransitionStart(event: any PresentationActionEvent) async {
        guard let restoration = await model.pendingPresentationRestoration(for: event.presentationControllerIdentifier) else {
            return
        }

        let navigation = NavigationPair(
            type: .transition,
            start: event.timestamp,
            screenName: restoration.name
        )

        await model.update(
            navigation: navigation,
            for: event.presentationControllerIdentifier
        )
    }

    private func finalizeRestorationTransition(event: any PresentationActionEvent) async {
        guard event.completed ?? true else {
            await model.removeNavigation(for: event.presentationControllerIdentifier)
            return
        }

        guard let restoration = await model.pendingPresentationRestoration(for: event.presentationControllerIdentifier) else {
            return
        }

        let existingNavigation = await model.navigation(for: event.presentationControllerIdentifier)
        let start = existingNavigation?.start ?? event.timestamp
        let previousScreenName = runtimeStateStore.previousScreenName

        updateCurrentScreen(
            state: restoration,
            start: start
        )

        let completedNavigation = NavigationPair(
            type: existingNavigation?.type ?? .transition,
            start: start,
            end: event.timestamp,
            screenName: restoration.name,
            lastScreenName: previousScreenName
        )

        send(navigation: completedNavigation)

        await model.removeNavigation(for: event.presentationControllerIdentifier)
        await model.removePendingPresentationRestoration(for: event.presentationControllerIdentifier)
    }
}
