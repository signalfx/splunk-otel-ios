//
/*
Copyright 2025 Splunk Inc.

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

extension Navigation {

    // MARK: - Instrumentation

    /// Starts detection and processing of navigation.
    func startDetection() {
        // NOTE:
        //
        // This is a temporary solution that will later be replaced by a more modern approach.
        //
        // However, there is currently insufficient support in `CiscoSwizzling`.
        // Once the support is implemented, the solution will adopt modern approach,
        // and the legacy solution will be removed.
        if Self.useLegacySolution {
            startLegacyDetection()
        }
        else {
            startModernDetection()
        }
    }


    // MARK: - Instrumentation (Modern solution)

    private func startModernDetection() {
        // swiftlint:disable:next unhandled_throwing_task
        Task(priority: .userInitiated) {
            let navigationStream = try await DefaultSwizzling.navigation

            // Process navigation events
            for await event in navigationStream where await shouldProcessEvent() {
                await processModernDetectionEvent(event)
            }
        }
    }

    private func processModernDetectionEvent(_ event: any NavigationActionEvent) async {
        let processedEvent = await processedModernDetectionEvent(from: event)

        // Supported events handling
        switch processedEvent.type {
        case .viewDidLoad:
            await processShowStart(event: processedEvent)

        case .viewDidAppear:
            await processNavigationEnd(event: processedEvent)

        case .willTransitionToTraitCollection:
            await processTransitionStart(event: processedEvent)

        case .didTransitionToTraitCollection:
            await processNavigationEnd(event: processedEvent)

        default:
            break
        }
    }

    private func processedModernDetectionEvent(from event: any NavigationActionEvent) async -> AutomatedNavigationEvent {
        let screenName = await preferredScreenName(for: event.controllerTypeName)

        if await model.isManualScreenName {
            return AutomatedNavigationEvent(
                timestamp: Date(),
                type: event.type,
                controllerTypeName: screenName,
                controllerIdentifier: event.controllerIdentifier
            )
        }

        let processedName = processAutomatedScreenName(
            eventScreenName: screenName,
            controllerIdentifier: event.controllerIdentifier
        )

        return AutomatedNavigationEvent(
            timestamp: Date(),
            type: event.type,
            controllerTypeName: processedName,
            controllerIdentifier: event.controllerIdentifier
        )
    }


    // MARK: - Instrumentation (Legacy solution)

    private func startLegacyDetection() {
        Task(priority: .userInitiated) {
            let willShowStream = NotificationCenter.default
                .notifications(for: Notification.Name(rawValue: "UINavigationControllerWillShowViewControllerNotification"))

            for await notification in willShowStream {
                if let event = await navigationEvent(for: notification.object, type: .viewDidLoad) {
                    await processShowStart(event: event)
                }
            }
        }

        Task(priority: .userInitiated) {
            let didShowStream = NotificationCenter.default
                .notifications(for: Notification.Name(rawValue: "UINavigationControllerDidShowViewControllerNotification"))

            for await notification in didShowStream {
                if let event = await navigationEvent(for: notification.object, type: .viewDidAppear) {
                    await processNavigationEnd(event: event)
                }
            }
        }

        Task(priority: .userInitiated) {
            let willTransitionStream = NotificationCenter.default
                .notifications(for: Notification.Name(rawValue: "UIPresentationControllerPresentationTransitionWillBeginNotification"))

            for await notification in willTransitionStream {
                if let event = await transitionEvent(for: notification.object, type: .willTransitionToTraitCollection) {
                    await processTransitionStart(event: event)
                }
            }
        }

        Task(priority: .userInitiated) {
            let didTransitionStream = NotificationCenter.default
                .notifications(for: Notification.Name(rawValue: "UIPresentationControllerPresentationTransitionDidEndNotification"))

            for await notification in didTransitionStream {
                if let event = await transitionEvent(for: notification.object, type: .didTransitionToTraitCollection) {
                    await processNavigationEnd(event: event)
                }
            }
        }
    }

    private func navigationEvent(for notificationObject: Any?, type eventType: NavigationActionEventType) async -> AutomatedNavigationEvent? {
        guard
            await shouldProcessEvent(),
            let navigationController = notificationObject as? UINavigationController,
            let visibleController = await navigationController.visibleViewController
        else {
            return nil
        }

        let controllerTypeName = preferredControllerName(for: visibleController)
        let screenName = await preferredScreenName(for: controllerTypeName)
        let controllerIdentifier = ObjectIdentifier(visibleController)
        let processedName: String

        if await model.isManualScreenName {
            processedName = screenName
        }
        else {
            processedName = processAutomatedScreenName(
                eventScreenName: screenName,
                controllerIdentifier: controllerIdentifier
            )
        }

        return AutomatedNavigationEvent(
            timestamp: Date(),
            type: eventType,
            controllerTypeName: processedName,
            controllerIdentifier: controllerIdentifier
        )
    }

    private func transitionEvent(for presentationObject: Any?, type eventType: NavigationActionEventType) async -> AutomatedNavigationEvent? {
        let presentationController = presentationObject as? UIPresentationController
        let uiViewController = presentationObject as? UIViewController
        let presentedController = await presentationController?.presentedViewController

        guard
            await shouldProcessEvent(),
            let visibleController = presentedController ?? uiViewController
        else {
            return nil
        }

        let controllerTypeName = preferredControllerName(for: visibleController)
        let screenName = await preferredScreenName(for: controllerTypeName)
        let controllerIdentifier = ObjectIdentifier(visibleController)
        let processedName: String

        if await model.isManualScreenName {
            processedName = screenName
        }
        else {
            processedName = processAutomatedScreenName(
                eventScreenName: screenName,
                controllerIdentifier: controllerIdentifier
            )
        }

        return AutomatedNavigationEvent(
            timestamp: Date(),
            type: eventType,
            controllerTypeName: processedName,
            controllerIdentifier: controllerIdentifier
        )
    }


    // MARK: - Navigation processing

    /// Process the beginning of the view controller display.
    private func processShowStart(event: NavigationActionEvent) async {
        let start = Date()

        let typeName = event.controllerTypeName
        let screenName = sanitize(typeName: typeName)
        let lastScreenName = await model.screenName

        let navigation = NavigationPair(
            type: .show,
            start: start,
            typeName: typeName,
            screenName: screenName
        )

        // Store this navigation for final processing
        await model.update(navigation: navigation, for: event.controllerIdentifier)
        await model.update(screenName: screenName)
        setCurrentScreenName(screenName)

        // Yield this change to the consumer
        // and send corresponding span
        if screenName != lastScreenName {
            continuation.yield(screenName)

            send(screenName: screenName, lastScreenName: lastScreenName, start: start)
        }
    }

    /// Process the beginning of the view controller transition.
    private func processTransitionStart(event: NavigationActionEvent) async {
        let start = Date()

        let typeName = event.controllerTypeName
        let screenName = sanitize(typeName: typeName)
        let lastScreenName = await model.screenName

        let navigation = NavigationPair(
            type: .transition,
            start: start,
            typeName: typeName,
            screenName: screenName
        )

        // Store this navigation for final processing
        await model.update(navigation: navigation, for: event.controllerIdentifier)

        // Send corresponding span
        if screenName != lastScreenName {
            send(screenName: screenName, lastScreenName: lastScreenName, start: start)
        }
    }

    /// Process the finalizing of the navigation.
    private func processNavigationEnd(event: NavigationActionEvent) async {
        let end = Date()
        let identifier = event.controllerIdentifier

        // Get corresponding navigation data
        guard let navigation = await model.navigation(for: identifier) else {
            return
        }

        var completedNavigation = navigation
        completedNavigation.end = end

        // Send corresponding span
        send(navigation: completedNavigation)

        // Remove finalized navigation from the model
        await model.removeNavigation(for: identifier)
    }


    // MARK: - Private methods

    /// Determine whether processing should occur at call time.
    private func shouldProcessEvent() async -> Bool {
        let moduleEnabled = await model.moduleEnabled
        let isManualScreenName = await model.isManualScreenName
        let trackingEnabled = state.isAutomatedTrackingEnabled || isManualScreenName

        return moduleEnabled && trackingEnabled
    }

    private func preferredScreenName(for controllerTypeName: String) async -> String {
        if await model.isManualScreenName {
            return await model.screenName
        }

        return controllerTypeName
    }

    private func processAutomatedScreenName(eventScreenName: String, controllerIdentifier: ObjectIdentifier) -> String {
        let event = NavigationEvent(
            screenName: eventScreenName,
            controllerIdentifier: controllerIdentifier
        )

        return navigationEventProcessor.process(event: event).screenName
    }
}
