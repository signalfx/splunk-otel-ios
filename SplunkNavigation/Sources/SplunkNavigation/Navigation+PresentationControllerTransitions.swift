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
        let timestamp: Date
    }


    // MARK: - Presentation controller transitions

    func processPresentationEvent(event: any PresentationActionEvent) async {
        // Filter on the controller whose screen name will be set:
        // presented for presentations, presenting for dismissals.
        switch event.type {
        case .presentationWillBegin:
            guard !Self.shouldIgnore(controllerTypeName: event.presentedControllerTypeName) else {
                return
            }

            await updateTransitionStart(for: presentedSnapshot(from: event))

        case .presentationDidEnd:
            guard !Self.shouldIgnore(controllerTypeName: event.presentedControllerTypeName) else {
                return
            }

            await finalizeTransition(
                for: presentedSnapshot(from: event),
                completed: event.completed ?? true
            )

        case .dismissalWillBegin:
            guard !Self.shouldIgnore(controllerTypeName: event.presentingControllerTypeName) else {
                return
            }

            await updateTransitionStart(for: presentingSnapshot(from: event))

        case .dismissalDidEnd:
            guard !Self.shouldIgnore(controllerTypeName: event.presentingControllerTypeName) else {
                return
            }

            await finalizeTransition(
                for: presentingSnapshot(from: event),
                completed: event.completed ?? true
            )

        @unknown default:
            break
        }
    }


    // MARK: - Private methods

    private func presentedSnapshot(from event: any PresentationActionEvent) -> PresentationTransitionSnapshot {
        PresentationTransitionSnapshot(
            controllerIdentifier: event.presentedControllerIdentifier,
            controllerTypeName: event.presentedControllerTypeName,
            timestamp: event.timestamp
        )
    }

    private func presentingSnapshot(from event: any PresentationActionEvent) -> PresentationTransitionSnapshot {
        PresentationTransitionSnapshot(
            controllerIdentifier: event.presentingControllerIdentifier,
            controllerTypeName: event.presentingControllerTypeName,
            timestamp: event.timestamp
        )
    }

    private func updateTransitionStart(for snapshot: PresentationTransitionSnapshot) async {
        let typeName = snapshot.controllerTypeName
        guard
            let navigationEvent = await processAutomatedNavigationEvent(
                sanitize(typeName: typeName),
                controllerIdentifier: snapshot.controllerIdentifier
            )
        else {
            return
        }

        let navigation = NavigationPair(
            type: .transition,
            start: snapshot.timestamp,
            typeName: typeName,
            screenName: navigationEvent.name
        )

        await model.update(
            navigation: navigation,
            for: snapshot.controllerIdentifier
        )
    }

    private func finalizeTransition(
        for snapshot: PresentationTransitionSnapshot,
        completed: Bool
    ) async {
        guard completed else {
            await model.removeNavigation(for: snapshot.controllerIdentifier)
            return
        }

        let typeName = snapshot.controllerTypeName

        guard
            let navigationEvent = await processAutomatedNavigationEvent(
                sanitize(typeName: typeName),
                controllerIdentifier: snapshot.controllerIdentifier
            )
        else {
            await model.removeNavigation(for: snapshot.controllerIdentifier)

            return
        }

        let screenName = navigationEvent.name
        let lastScreenName = await model.screenName

        if await model.navigation(for: snapshot.controllerIdentifier) == nil {
            let fallbackNavigation = NavigationPair(
                type: .transition,
                start: snapshot.timestamp,
                typeName: typeName,
                screenName: screenName
            )
            await model.update(
                navigation: fallbackNavigation,
                for: snapshot.controllerIdentifier
            )
        }

        let start =
            await model.navigation(for: snapshot.controllerIdentifier)?
            .start ?? snapshot.timestamp

        await updateCurrentScreen(
            screenName: screenName,
            lastScreenName: lastScreenName,
            start: start,
            attributes: navigationEvent.attributes
        )

        let event = AutomatedNavigationEvent(
            timestamp: snapshot.timestamp,
            type: .didTransitionToTraitCollection,
            controllerTypeName: typeName,
            controllerIdentifier: snapshot.controllerIdentifier
        )

        await processNavigationEnd(event: event)
    }
}
