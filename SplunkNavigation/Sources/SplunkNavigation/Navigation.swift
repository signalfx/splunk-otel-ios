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

internal import CiscoLogger
internal import CiscoSwizzling

import Foundation
import SplunkCommon

import UIKit

/// The navigation module detects and tracks navigation in the application.
public final class Navigation: Sendable {

    // MARK: - Static constants

    // It is used to switch the implementation for testing
    // and during further development of the module
    private static let useLegacySolution = true


    // MARK: - Private

    let model = NavigationModel()

    let appBundleName: String?
    private let continuation: AsyncStream<String>.Continuation

    private let logger = DefaultLogAgent(
        poolName: PackageIdentifier.instance(),
        category: "Navigation"
    )


    // MARK: - Public

    /// Asynchronous stream of screen name changes.
    public let screenNameStream: AsyncStream<String>


    // MARK: - Module configuration

    /// A configured version of the agent.
    public var agentVersion: String? {
        get async {
            await model.agentVersion
        }
    }

    /// Sets used version of the agent. It should correspond to the `SplunkRum.version`.
    ///
    /// - Parameter agentVersion: A configured version of the agent.
    ///
    /// - Returns: An updated module object.
    @discardableResult
    public func agentVersion(_ agentVersion: String) -> Self {
        Task {
            if await agentVersion != self.agentVersion {
                await model.update(agentVersion: agentVersion)
            }
        }

        return self
    }


    // MARK: - Preferences

    /// An object that holds preferred settings for the module.
    public nonisolated(unsafe) var preferences = Preferences() {
        didSet {
            preferences.module = self
            update()
        }
    }


    // MARK: - State

    /// An object reflects the current state and settings used for the module.
    public let state = RuntimeState()


    // MARK: - Initialization

    // Module protocol conformance
    public required init() {
        // Prepare a stream for screen name changes
        let (screenNameStream, continuation) = AsyncStream.makeStream(of: String.self)
        self.screenNameStream = screenNameStream
        self.continuation = continuation

        // Get bundle name for the guest application
        appBundleName = Self.applicationBundleName()

        if appBundleName == nil {
            logger.log(level: .debug) {
                "Couldn't determine bundle name for the main application bundle."
            }
        }

        preferences.module = self
    }


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

        } else {
            startModernDetection()
        }
    }


    // MARK: - Instrumentation (Modern solution)

    private func startModernDetection() {
        Task(priority: .userInitiated) {
            let navigationStream = try await DefaultSwizzling.navigation

            // Process navigation events
            for await event in navigationStream {
                guard state.isAutomatedTrackingEnabled else {
                    continue
                }

                switch event.type {
                case .viewDidLoad:
                    await processShowStart(event: event)

                case .viewDidAppear:
                    await processNavigationEnd(event: event)

                case .willTransitionToTraitCollection:
                    await processTransitionStart(event: event)

                case .didTransitionToTraitCollection:
                    await processNavigationEnd(event: event)

                default:
                    break
                }
            }
        }
    }


    // MARK: - Instrumentation (Legacy solution)

    private func startLegacyDetection() {
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

    private func navigationEvent(for notificationObject: Any?, type eventType: NavigationActionEventType) async -> AutomatedNavigationEvent? {
        guard
            state.isAutomatedTrackingEnabled,
            let navigationController = notificationObject as? UINavigationController,
            let visibleController = await navigationController.visibleViewController
        else {
            return nil
        }

        return AutomatedNavigationEvent(
            type: eventType,
            controllerTypeName: NSStringFromClass(type(of: visibleController)),
            controllerIdentifier: ObjectIdentifier(visibleController)
        )
    }

    private func transitionEvent(for presentationObject: Any?, type eventType: NavigationActionEventType) async -> AutomatedNavigationEvent? {
        guard
            state.isAutomatedTrackingEnabled,
            let presentationController = presentationObject as? UIPresentationController
        else {
            return nil
        }

        let visibleController = await presentationController.presentedViewController

        return AutomatedNavigationEvent(
            type: eventType,
            controllerTypeName: NSStringFromClass(type(of: visibleController)),
            controllerIdentifier: ObjectIdentifier(visibleController)
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

        // Yield this change to the consumer
        continuation.yield(screenName)

        // Send corresponding span
        send(screenName: screenName, lastScreenName: lastScreenName, start: start)
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
        send(screenName: screenName, lastScreenName: lastScreenName, start: start)
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


    // MARK: - State management

    /// Updates the module to the desired state according to the current preferences.
    func update() {
        // Update state
        state.isAutomatedTrackingEnabled = preferences.enableAutomatedTracking ?? false
    }


    // MARK: - Class name sanitization

    /// Returns the bundle name for the guest application.
    private static func applicationBundleName() -> String? {
        Bundle.main.object(forInfoDictionaryKey: kCFBundleNameKey as String) as? String
    }

    /// Drops module prefix for types from the application naming space.
    private func sanitize(typeName: String) -> String {
        guard
            let bundleName = appBundleName,
            typeName.hasPrefix(bundleName)
        else {
            return typeName
        }

        let prefix = "\(bundleName)."

        return String(typeName.dropFirst(prefix.count))
    }
}
