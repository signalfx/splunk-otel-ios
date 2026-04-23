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
import CiscoSwizzling
import Foundation
import SplunkCommon
import UIKit

/// The navigation module detects and tracks navigation in the application.
public final class Navigation: Sendable {

    // MARK: - Private

    let model = NavigationModel()

    let appBundleName: String?
    let continuation: AsyncStream<String>.Continuation
    let navigationEventStreamProvider: any NavigationEventStreamProviding

    private let logger = DefaultLogAgent(
        poolName: PackageIdentifier.instance(),
        category: "Navigation"
    )

    // MARK: - Public

    /// Asynchronous stream of screen name changes.
    public let screenNameStream: AsyncStream<String>

    /// Processor used to transform automated navigation events before they produce spans.
    ///
    /// Assigned once during ``install(with:remoteConfiguration:)`` and must not be
    /// mutated after detection has started. Manual ``track(screen:)`` calls bypass
    /// the processor.
    nonisolated(unsafe) var navigationEventProcessor: any NavigationEventProcessor


    // MARK: - Module configuration

    /// A configured version of the agent.
    public var agentVersion: String? {
        get async {
            await model.agentVersion
        }
    }

    /// Sets used version of the agent.
    ///
    /// It should correspond to the `SplunkRum.version`.
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

    /// Module protocol conformance.
    public required convenience init() {
        self.init(
            navigationEventStreamProvider: DefaultNavigationEventStreamProvider()
        )
    }

    init(
        navigationEventStreamProvider: any NavigationEventStreamProviding,
        navigationEventProcessor: any NavigationEventProcessor = DefaultNavigationEventProcessor()
    ) {
        self.navigationEventStreamProvider = navigationEventStreamProvider
        self.navigationEventProcessor = navigationEventProcessor
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
        Task(priority: .userInitiated) {
            await runNavigationDetectionLoop()
        }

        Task(priority: .userInitiated) {
            await runPresentationDetectionLoop()
        }
    }

    private func runNavigationDetectionLoop() async {
        do {
            let stream = try await navigationStream()

            for await event in stream {
                guard
                    await shouldProcessEvent(),
                    !Self.shouldIgnore(controllerTypeName: event.controllerTypeName)
                else {
                    continue
                }

                if await isNavigationControllerManaged(event: event) {
                    continue
                }

                await processNavigationEvent(event)
            }
        }
        catch {
            logger.log(level: .error) {
                "Failed to initialize navigation stream: \(String(describing: error))"
            }
        }
    }

    private func runPresentationDetectionLoop() async {
        do {
            let stream = try await presentationStream()

            for await event in stream where await shouldProcessEvent() {

                await processPresentationEvent(event: event)
            }
        }
        catch {
            logger.log(level: .error) {
                "Failed to initialize presentation stream: \(String(describing: error))"
            }
        }
    }

    private func processNavigationEvent(_ event: NavigationActionEvent) async {
        switch event.type {
        case .viewDidLoad:
            await processShowStart(event: event)

        case .viewWillTransition,
            .willTransitionToTraitCollection:
            await processTransitionStart(event: event)

        case .didTransitionToTraitCollection,
            .viewDidAppear,
            .viewDidDisappear,
            .viewDidTransition:
            await processNavigationEnd(event: event)

        case .navigationControllerWillShow:
            await processNavigationControllerWillShow(event: event)

        case .navigationControllerDidShow:
            await processNavigationControllerDidShow(event: event)


        default:
            break
        }
    }


    // MARK: - Navigation processing

    /// Process the beginning of the view controller display.
    private func processShowStart(event: NavigationActionEvent) async {
        let start = Date()

        let typeName = event.controllerTypeName
        guard
            let navigationEvent = processAutomatedNavigationEvent(
                sanitize(typeName: typeName),
                controllerIdentifier: event.controllerIdentifier
            )
        else {
            return
        }

        let screenName = navigationEvent.name
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
        // and send corresponding span
        if screenName != lastScreenName {
            continuation.yield(screenName)

            send(
                screenName: screenName,
                lastScreenName: lastScreenName,
                start: start,
                attributes: navigationEvent.attributes
            )
        }
    }

    /// Process the beginning of the view controller transition.
    private func processTransitionStart(event: NavigationActionEvent) async {
        let start = Date()

        let typeName = event.controllerTypeName
        guard
            let navigationEvent = processAutomatedNavigationEvent(
                sanitize(typeName: typeName),
                controllerIdentifier: event.controllerIdentifier
            )
        else {
            return
        }

        let screenName = navigationEvent.name
        let lastScreenName = await model.screenName

        let navigation = NavigationPair(
            type: .transition,
            start: start,
            typeName: typeName,
            screenName: screenName
        )

        // Always refresh in-flight transition state for this controller.
        // If a previous end event was missed, this replaces stale timing data.
        await model.update(navigation: navigation, for: event.controllerIdentifier)
        await model.update(screenName: screenName)

        // Yield this change to the consumer and send corresponding span
        if screenName != lastScreenName {
            continuation.yield(screenName)
            send(
                screenName: screenName,
                lastScreenName: lastScreenName,
                start: start,
                attributes: navigationEvent.attributes
            )
        }
    }

    /// Process the finalizing of the navigation.
    func processNavigationEnd(event: NavigationActionEvent) async {
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


    // MARK: - Private methods

    /// Determine whether processing should occur at call time.
    private func shouldProcessEvent() async -> Bool {
        let moduleEnabled = await model.moduleEnabled
        let trackingEnabled = state.isAutomatedTrackingEnabled

        return moduleEnabled && trackingEnabled
    }

    /// Checks whether the event belongs to a view controller whose lifecycle is managed
    /// by a `UINavigationController` transition.
    ///
    /// When a navigation controller push or pop is in flight, the child controller also fires
    /// its own `viewDidLoad` / `viewDidAppear` events. Processing those independently would
    /// create duplicate screen-name updates and navigation spans. This guard suppresses the
    /// redundant lifecycle events so that only the navigation-controller transition path
    /// (`willShow` / `didShow`) drives the screen change.
    private func isNavigationControllerManaged(event: NavigationActionEvent) async -> Bool {
        switch event.type {
        case .viewDidAppear,
            .viewDidLoad:
            await model.isManagedNavigationControllerTarget(event.controllerIdentifier)

        default:
            false
        }
    }


    /// Passes the sanitized type name through the ``navigationEventProcessor``
    /// and returns the processed event, or `nil` if the event was suppressed.
    func processAutomatedNavigationEvent(
        _ typeName: String,
        controllerIdentifier: ObjectIdentifier
    ) -> NavigationEvent? {
        let controllerIdentity = String(UInt(bitPattern: controllerIdentifier))

        return navigationEventProcessor.onViewController(
            typeName: typeName,
            controllerIdentity: controllerIdentity
        )
    }

    func preferredControllerName(for controller: UIViewController) -> String {
        String(describing: type(of: controller))
    }
}
