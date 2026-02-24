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

    /// Detection solution switch.
    ///
    /// It is used to switch the implementation for testing
    /// and during further development of the module
    static let useLegacySolution = true


    // MARK: - Private

    let model = NavigationModel()

    let appBundleName: String?
    let continuation: AsyncStream<String>.Continuation

    private let logger = DefaultLogAgent(
        poolName: PackageIdentifier.instance(),
        category: "Navigation"
    )

    private let currentScreenNameLock = NSLock()
    private var currentScreenNameValue: String?


    // MARK: - Public

    /// Asynchronous stream of screen name changes.
    public let screenNameStream: AsyncStream<String>

    /// Processes automated navigation events.
    ///
    /// Manual ``track(screen:attributes:)`` calls bypass this processor.
    public nonisolated(unsafe) var navigationEventProcessor: any NavigationEventProcessor = DefaultNavigationEventProcessor()

    /// The most recently tracked screen name.
    ///
    /// This value is updated by both automatic and manual tracking.
    public var currentScreenName: String? {
        currentScreenNameLock.lock()
        defer { currentScreenNameLock.unlock() }

        return currentScreenNameValue
    }


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

    // MARK: - State management

    /// Updates the module to the desired state according to the current preferences.
    func update() {
        // Update state
        state.isAutomatedTrackingEnabled = preferences.enableAutomatedTracking ?? false
    }


    func preferredControllerName(for controller: UIViewController) -> String {
        String(describing: type(of: controller))
    }

    func setCurrentScreenName(_ name: String?) {
        currentScreenNameLock.lock()
        defer { currentScreenNameLock.unlock() }

        currentScreenNameValue = name
    }
}
