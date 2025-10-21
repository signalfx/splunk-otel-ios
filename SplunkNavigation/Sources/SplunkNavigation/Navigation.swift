//
/*
Copyright 2024 Splunk Inc.

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

import Combine
import Foundation
import OpenTelemetryApi
import SplunkCommon
import UIKit

/// Navigation module.
public final class Navigation: Sendable {

    // MARK: - Public

    /// Navigation preferences.
    public var preferences: NavigationPreferences {
        get {
            model.unsafePreferences
        }
        set {
            Task {
                await model.update(preferences: newValue)
            }
        }
    }

    // MARK: - Internal

    /// Logger for the module.
    let logger = DefaultLogAgent(category: "SplunkNavigation")

    /// Internal actor for state management.
    let model = NavigationModel()

    /// Designated initializer.
    init() {
        Task {
            if await preferences.enableAutomatedTracking {
                enable()
            }
        }
    }

    /// Enables automated tracking of navigation events.
    public func enable() {
        Task {
            await model.update(isEnabled: true)
            startLegacyDetection()
        }
    }

    /// Disables automated tracking of navigation events.
    public func disable() {
        Task {
            await model.update(isEnabled: false)
        }
    }

    /// Sets a screen name for a given view controller type.
    public func setScreenName(_ name: String, for viewController: UIViewController.Type) {
        Task {
            await model.setScreenName(name, for: viewController)
        }
    }

    /// Reports a screen name manually.
    public func reportScreenName(_ name: String) {
        Task {
            await model.reportScreenName(name)
        }
    }

    // MARK: - Private

    private func processShowStart(event: AutomatedNavigationEvent) async {
        guard await model.isEnabled else {
            return
        }

        // If we have set manual naming, then we prefer it
        if await model.isManualScreenName {
            let processedEvent = await AutomatedNavigationEvent(
                timestamp: Date(),
                type: event.type,
                controllerTypeName: model.manualScreenName,
                controllerIdentifier: event.controllerIdentifier
            )
            await model.processShowStart(event: processedEvent)
        }
        else {
            await model.processShowStart(event: event)
        }
    }

    private func processTransitionStart(event: AutomatedNavigationEvent) async {
        guard await model.isEnabled else {
            return
        }

        await model.processTransitionStart(event: event)
    }

    private func processNavigationEnd(event: AutomatedNavigationEvent) async {
        guard await model.isEnabled else {
            return
        }

        await model.processNavigationEnd(event: event)
    }

    private func preferredScreenName(for controllerTypeName: String) async -> String {
        await model.screenName(for: controllerTypeName) ?? controllerTypeName
    }

    // MARK: - Instrumentation (Legacy solution)

    private func startLegacyDetection() {
        if #available(iOS 15.0, *) {
            startModernLegacyDetection()
        }
        else {
            startClassicLegacyDetection()
        }
    }

    @available(iOS 15.0, *)
    private func startModernLegacyDetection() {
        Task(priority: .userInitiated) {
            let willShowStream = NotificationCenter.default
                .publisher(for: Notification.Name(rawValue: "UINavigationControllerWillShowViewControllerNotification"))
                .values

            for await notification in willShowStream {
                if let event = await navigationEvent(for: notification.object, type: .viewDidLoad) {
                    await processShowStart(event: event)
                }
            }
        }

        Task(priority: .userInitiated) {
            let didShowStream = NotificationCenter.default
                .publisher(for: Notification.Name(rawValue: "UINavigationControllerDidShowViewControllerNotification"))
                .values

            for await notification in didShowStream {
                if let event = await navigationEvent(for: notification.object, type: .viewDidAppear) {
                    await processNavigationEnd(event: event)
                }
            }
        }

        Task(priority: .userInitiated) {
            let willTransitionStream = NotificationCenter.default
                .publisher(for: Notification.Name(rawValue: "UIPresentationControllerPresentationTransitionWillBeginNotification"))
                .values

            for await notification in willTransitionStream {
                if let event = await transitionEvent(for: notification.object, type: .willTransitionToTraitCollection) {
                    await processTransitionStart(event: event)
                }
            }
        }

        Task(priority: .userInitiated) {
            let didTransitionStream = NotificationCenter.default
                .publisher(for: Notification.Name(rawValue: "UIPresentationControllerPresentationTransitionDidEndNotification"))
                .values

            for await notification in didTransitionStream {
                if let event = await transitionEvent(for: notification.object, type: .didTransitionToTraitCollection) {
                    await processNavigationEnd(event: event)
                }
            }
        }
    }

    private func startClassicLegacyDetection() {
        NotificationCenter.default.addObserver(
            forName: Notification.Name(rawValue: "UINavigationControllerWillShowViewControllerNotification"),
            object: nil,
            queue: nil
        ) { notification in
            Task {
                if let event = await self.navigationEvent(for: notification.object, type: .viewDidLoad) {
                    await self.processShowStart(event: event)
                }
            }
        }
        NotificationCenter.default.addObserver(
            forName: Notification.Name(rawValue: "UINavigationControllerDidShowViewControllerNotification"),
            object: nil,
            queue: nil
        ) { notification in
            Task {
                if let event = await self.navigationEvent(for: notification.object, type: .viewDidAppear) {
                    await self.processNavigationEnd(event: event)
                }
            }
        }
        NotificationCenter.default.addObserver(
            forName: Notification.Name(rawValue: "UIPresentationControllerPresentationTransitionWillBeginNotification"),
            object: nil,
            queue: nil
        ) { notification in
            Task {
                if let event = await self.transitionEvent(for: notification.object, type: .willTransitionToTraitCollection) {
                    await self.processTransitionStart(event: event)
                }
            }
        }
        NotificationCenter.default.addObserver(
            forName: Notification.Name(rawValue: "UIPresentationControllerPresentationTransitionDidEndNotification"),
            object: nil,
            queue: nil
        ) { notification in
            Task {
                if let event = await self.transitionEvent(for: notification.object, type: .didTransitionToTraitCollection) {
                    await self.processNavigationEnd(event: event)
                }
            }
        }
    }

    private func navigationEvent(for object: Any?, type eventType: AutomatedNavigationEventType) async -> AutomatedNavigationEvent? {
        guard let navigationController = object as? UINavigationController,
            let visibleController = navigationController.visibleViewController
        else {
            return nil
        }

        let controllerTypeName = String(describing: type(of: visibleController))
        let screenName = await preferredScreenName(for: controllerTypeName)

        return AutomatedNavigationEvent(
            timestamp: Date(),
            type: eventType,
            controllerTypeName: screenName,
            controllerIdentifier: ObjectIdentifier(visibleController)
        )
    }

    private func transitionEvent(for object: Any?, type eventType: AutomatedNavigationEventType) async -> AutomatedNavigationEvent? {
        guard let presentationController = object as? UIPresentationController,
            let visibleController = presentationController.presentedViewController
        else {
            return nil
        }

        let controllerTypeName = String(describing: type(of: visibleController))
        let screenName = await preferredScreenName(for: controllerTypeName)

        return AutomatedNavigationEvent(
            timestamp: Date(),
            type: eventType,
            controllerTypeName: screenName,
            controllerIdentifier: ObjectIdentifier(visibleController)
        )
    }
}
