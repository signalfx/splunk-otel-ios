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

import Foundation
internal import OpenTelemetryApi
import SplunkCommon

/// The emitted navigation screen state used for automated deduplication.
struct NavigationScreenState: Equatable {
    let name: String
    let attributes: [String: AttributeValue]
}

/// Result of updating the stored navigation screen state.
struct NavigationScreenStateUpdate {
    /// The previous screen name, or `nil` if no real screen had been shown yet.
    let previousName: String?
    let shouldEmit: Bool
}

/// Synchronous, lock-protected store for navigation state that must be readable
/// without an actor hop.
///
/// ## Why a lock instead of an actor?
///
/// `track(screen:attributes:)` is a public synchronous API: callers invoke it
/// without `await` and it must complete on the caller's thread. Swift actors
/// cannot be accessed synchronously from outside their own isolation domain,
/// so an actor would force `track(screen:)` to become `async` — a breaking
/// change to the public API.
///
/// Automated navigation detection runs in async `Task` contexts started by
/// `startDetection()`. Manual tracking runs on whatever thread the host app
/// calls from. The `NSLock` bridges these two concurrency domains, allowing
/// both paths to safely read and write shared screen state without coupling
/// the public API to Swift concurrency.
///
/// ## What is stored here?
///
/// - `screenState` — updated on every navigation event; read by both automated
///   tasks and `track(screen:)` for deduplication. `nil` means no real screen
///   has been shown yet (including after a modal is dismissed over a no-screen
///   state); this is distinct from a customer explicitly tracking a screen
///   named `"unknown"`.
/// - `moduleEnabled` — checked synchronously by `track(screen:)` before emitting.
/// - `sharedState` — injected by the agent after construction; read from both
///   automated tasks and synchronous manual-tracking calls.
final class NavigationRuntimeStateStore: @unchecked Sendable {

    // MARK: - Private

    private let lock = NSLock()
    private weak var storedSharedState: AgentSharedState?
    private var storedModuleEnabled: Bool = true
    private var storedScreenState: NavigationScreenState?


    // MARK: - Shared state

    var sharedState: AgentSharedState? {
        lock.withLock { storedSharedState }
    }

    func setSharedState(_ sharedState: AgentSharedState?) {
        lock.withLock { storedSharedState = sharedState }
    }


    // MARK: - Module enabled

    var moduleEnabled: Bool {
        lock.withLock { storedModuleEnabled }
    }

    func setModuleEnabled(_ enabled: Bool) {
        lock.withLock { storedModuleEnabled = enabled }
    }


    // MARK: - Screen name

    var screenName: String {
        lock.withLock { storedScreenState?.name ?? "unknown" }
    }

    var screenState: NavigationScreenState? {
        lock.withLock { storedScreenState }
    }

    /// Resets the stored screen state to nil, as if no screen has been shown.
    func resetScreenState() {
        lock.withLock { storedScreenState = nil }
    }

    /// Atomically updates the stored screen state.
    @discardableResult
    func updateScreenState(
        _ state: NavigationScreenState,
        forceEmit: Bool
    ) -> NavigationScreenStateUpdate {
        lock.withLock {
            let previous = storedScreenState
            storedScreenState = state

            return NavigationScreenStateUpdate(
                previousName: previous?.name,
                shouldEmit: forceEmit || previous != state
            )
        }
    }
}
