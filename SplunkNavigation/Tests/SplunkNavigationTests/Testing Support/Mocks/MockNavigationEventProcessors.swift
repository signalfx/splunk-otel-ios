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
@testable import SplunkNavigation

// MARK: - Test processors

final class PrefixingProcessor: NavigationEventProcessor {
    let prefix: String

    init(prefix: String) {
        self.prefix = prefix
    }

    func onViewController(typeName: String, controllerIdentity _: String) -> NavigationEvent? {
        NavigationEvent(name: "\(prefix)/\(typeName)")
    }
}

final class NameOverridingProcessor: NavigationEventProcessor {
    func onViewController(typeName _: String, controllerIdentity _: String) -> NavigationEvent? {
        NavigationEvent(name: "OverriddenName")
    }
}

final class SuppressingProcessor: NavigationEventProcessor {
    func onViewController(typeName _: String, controllerIdentity _: String) -> NavigationEvent? {
        nil
    }
}

final class CountingProcessor: NavigationEventProcessor, @unchecked Sendable {
    private let lock = NSLock()
    private var storedCallCount = 0

    var callCount: Int {
        lock.lock()
        defer { lock.unlock() }

        return storedCallCount
    }

    func onViewController(typeName: String, controllerIdentity _: String) -> NavigationEvent? {
        lock.lock()
        defer { lock.unlock() }

        storedCallCount += 1

        return NavigationEvent(name: typeName)
    }
}

final class SequenceNavigationEventProcessor: NavigationEventProcessor, @unchecked Sendable {
    private let lock = NSLock()
    private let events: [NavigationEvent]
    private var nextIndex = 0

    init(events: [NavigationEvent]) {
        self.events = events
    }

    func onViewController(typeName: String, controllerIdentity _: String) -> NavigationEvent? {
        lock.lock()
        defer {
            nextIndex += 1
            lock.unlock()
        }

        guard !events.isEmpty else {
            return NavigationEvent(name: typeName)
        }

        let eventIndex = min(nextIndex, events.count - 1)
        return events[eventIndex]
    }
}

/// Returns the event with attributes that attempt to override all SDK-reserved span keys.
final class ReservedKeyOverrideProcessor: NavigationEventProcessor {
    func onViewController(typeName: String, controllerIdentity _: String) -> NavigationEvent? {
        NavigationEvent(
            name: typeName,
            attributes: [
                "screen.name": "hacker",
                "last.screen.name": "hacker",
                "component": "hacker",
                "navigation.name": "hacker"
            ]
        )
    }
}
