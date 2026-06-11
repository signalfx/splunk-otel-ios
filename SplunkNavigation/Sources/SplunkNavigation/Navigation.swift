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

    @_spi(SplunkTesting)
    public let model: NavigationModel

    let appBundleName: String?

    /// Yielded from multiple concurrent contexts.
    let continuation: AsyncStream<String>.Continuation
    @_spi(SplunkTesting)
    public let navigationEventStreamProvider: any NavigationEventStreamProviding

    private let logger = DefaultLogAgent(
        poolName: PackageIdentifier.instance(),
        category: "Navigation"
    )

    private let screenNameObserverStore = ScreenNameObserverStore()

    @_spi(SplunkTesting)
    public let runtimeStateStore = NavigationRuntimeStateStore()

    // MARK: - Public

    /// Asynchronous stream of screen name changes.
    public let screenNameStream: AsyncStream<String>


    // MARK: - Screen name observer

    /// Registers a synchronous observer that is called on every screen-name change
    /// before the change is yielded to `screenNameStream`.
    ///
    /// The agent uses this hook to update runtime attributes synchronously, ensuring
    /// spans started immediately after a screen-name change carry the new value.
    @_spi(SplunkInternal)
    @_spi(SplunkTesting)
    public func setScreenNameObserver(_ observer: (@Sendable (String) -> Void)?) {
        screenNameObserverStore.set(observer)
    }

    /// Publishes a screen-name change to the synchronous observer and then to the async stream.
    func publishScreenNameChange(_ name: String) {
        screenNameObserverStore.publish(name)
        continuation.yield(name)
    }

    // MARK: - Module configuration

    /// Shared agent state, injected by the agent at startup.
    public var sharedState: AgentSharedState? {
        get {
            runtimeStateStore.sharedState
        }
        set {
            runtimeStateStore.setSharedState(newValue)
        }
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

    @_spi(SplunkTesting)
    public init(
        navigationEventStreamProvider: any NavigationEventStreamProviding,
        navigationEventProcessor: any NavigationEventProcessor = DefaultNavigationEventProcessor()
    ) {
        self.navigationEventStreamProvider = navigationEventStreamProvider
        model = NavigationModel(navigationEventProcessor: navigationEventProcessor)

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

    /// Starts long-lived detection loops that run for the lifetime of this
    /// instance.
    ///
    /// These tasks strongly capture `self` with no self-termination
    /// path; an accepted trade-off for a module that runs for the lifetime
    /// of the process. If cancellation were ever needed, the task handles
    /// would need to be stored and `.cancel()` called explicitly.
    @_spi(SplunkTesting)
    public func startDetection() {
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
                    !shouldIgnoreAndLog(controllerTypeName: event.controllerTypeName)
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
        case .viewDidAppear:
            await processShowCommit(event: event)

        case .viewDidLoad:
            await processShowStart(event: event)

        case .viewDidDisappear:
            await cleanupPendingNavigation(event: event)

        case .didTransitionToTraitCollection,
            .viewDidTransition,
            .viewWillTransition,
            .willTransitionToTraitCollection:
            break

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
        let navigation = NavigationPair(
            type: .show,
            start: event.timestamp,
            screenName: sanitize(typeName: event.controllerTypeName)
        )

        await model.update(navigation: navigation, for: event.controllerIdentifier)
    }

    /// Process the committed view controller display.
    private func processShowCommit(event: NavigationActionEvent) async {
        await commitNavigation(event: event, fallbackType: .show)
    }

    /// Drop a pending direct show that never reached a committed visible state.
    private func cleanupPendingNavigation(event: NavigationActionEvent) async {
        await model.removeNavigation(for: event.controllerIdentifier)
    }

    /// Process the finalizing of the navigation.
    func processNavigationEnd(event: NavigationActionEvent) async {
        let end = event.timestamp
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

    /// Process, publish, and finalize a committed automated navigation.
    @discardableResult
    func commitNavigation(event: NavigationActionEvent, fallbackType: NavigationType) async -> Bool {
        let typeName = event.controllerTypeName
        let identifier = event.controllerIdentifier

        guard
            let navigationEvent = await processAutomatedNavigationEvent(
                sanitize(typeName: typeName),
                controllerIdentifier: identifier
            )
        else {
            await model.removeNavigation(for: identifier)
            return false
        }

        let existingNavigation = await model.navigation(for: identifier)
        let start = existingNavigation?.start ?? event.timestamp

        let previousScreenName = updateCurrentScreen(
            screenName: navigationEvent.name,
            start: start,
            attributes: navigationEvent.attributes
        )

        let navigation = NavigationPair(
            type: existingNavigation?.type ?? fallbackType,
            start: start,
            screenName: navigationEvent.name,
            lastScreenName: previousScreenName
        )
        await model.update(navigation: navigation, for: identifier)

        let endEvent = AutomatedNavigationEvent(
            timestamp: event.timestamp,
            type: .viewDidAppear,
            controllerTypeName: typeName,
            controllerIdentifier: identifier
        )

        await processNavigationEnd(event: endEvent)
        return true
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

    /// Returns whether the controller should be filtered from automatic
    /// navigation tracking, and logs at debug level when filtering occurs.
    ///
    /// The static ``shouldIgnore(controllerTypeName:)`` remains pure for
    /// testability; this instance method adds the side effect of logging
    /// so that filtered controller names are observable in debug builds.
    @_spi(SplunkTesting)
    public func shouldIgnoreAndLog(controllerTypeName: String) -> Bool {
        guard Self.shouldIgnore(controllerTypeName: controllerTypeName) else {
            return false
        }

        logger.log(level: .debug) {
            "Filtered internal controller from automatic navigation tracking: \(controllerTypeName)"
        }
        return true
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


    /// Passes the sanitized type name through the navigation event processor
    /// (stored on the ``NavigationModel`` actor) and returns the processed event,
    /// or `nil` if the event was suppressed.
    @_spi(SplunkTesting)
    public func processAutomatedNavigationEvent(
        _ typeName: String,
        controllerIdentifier: ObjectIdentifier
    ) async -> NavigationEvent? {
        let controllerIdentity = String(UInt(bitPattern: controllerIdentifier))

        return await model.navigationEventProcessor.onViewController(
            typeName: typeName,
            controllerIdentity: controllerIdentity
        )
    }

    @_spi(SplunkTesting)
    public func preferredControllerName(for controller: UIViewController) -> String {
        String(describing: type(of: controller))
    }
}
