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

    func processPresentationEvent(
        event: any PresentationActionEvent
    ) async {
        guard await shouldProcessAutomatedPresentationEvent() else {
            return
        }

        switch event.type {
        case .presentationWillBegin:
            await updateTransitionStart(for: presentedSnapshot(from: event))

        case .presentationDidEnd:
            await finalizeTransition(
                for: presentedSnapshot(from: event),
                completed: event.completed ?? true
            )

        case .dismissalWillBegin:
            await updateTransitionStart(for: presentingSnapshot(from: event))

        case .dismissalDidEnd:
            await finalizeTransition(
                for: presentingSnapshot(from: event),
                completed: event.completed ?? true
            )
        }
    }


    // MARK: - Private methods

    private func shouldProcessAutomatedPresentationEvent() async -> Bool {
        let moduleEnabled = await model.moduleEnabled
        return moduleEnabled && state.isAutomatedTrackingEnabled
    }

    private func presentedSnapshot(
        from event: any PresentationActionEvent
    ) -> PresentationTransitionSnapshot {
        PresentationTransitionSnapshot(
            controllerIdentifier: event.presentedControllerIdentifier,
            controllerTypeName: event.presentedControllerTypeName
        )
    }

    private func presentingSnapshot(
        from event: any PresentationActionEvent
    ) -> PresentationTransitionSnapshot {
        PresentationTransitionSnapshot(
            controllerIdentifier: event.presentingControllerIdentifier,
            controllerTypeName: event.presentingControllerTypeName
        )
    }

    private func updateTransitionStart(
        for snapshot: PresentationTransitionSnapshot
    ) async {
        let typeName = snapshot.controllerTypeName
        let screenName = sanitize(typeName: typeName)

        let navigation = NavigationPair(
            type: .transition,
            start: Date(),
            typeName: typeName,
            screenName: screenName
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
        let screenName = sanitize(typeName: typeName)
        let lastScreenName = await model.screenName

        if await model.navigation(for: snapshot.controllerIdentifier) == nil {
            let fallbackNavigation = NavigationPair(
                type: .transition,
                start: Date(),
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
            .start ?? Date()

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
            type: .didTransitionToTraitCollection,
            controllerTypeName: typeName,
            controllerIdentifier: snapshot.controllerIdentifier
        )

        await processNavigationEnd(event: event)
    }
}
