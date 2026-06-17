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

internal import CiscoSwizzling
import Foundation

@testable import SplunkNavigation

func makeTransitionEvent(
    type: NavigationActionEventType,
    navigationControllerIdentifier: ObjectIdentifier,
    controllerIdentifier: ObjectIdentifier,
    controllerTypeName: String
) -> MockNavigationActionEvent {
    MockNavigationActionEvent(
        timestamp: Date(),
        type: type,
        navigationControllerIdentifier: navigationControllerIdentifier,
        controllerTypeName: controllerTypeName,
        controllerIdentifier: controllerIdentifier
    )
}

func makeEventStream(
    _ events: [any NavigationActionEvent]
) -> AsyncStream<any NavigationActionEvent> {
    AsyncStream<any NavigationActionEvent> { continuation in
        for event in events {
            continuation.yield(event)
        }
        continuation.finish()
    }
}


// MARK: - Screen name assertions

extension Navigation {
    var currentScreenNameForTesting: String {
        runtimeStateStore.screenName
    }
}


// MARK: - Screen name observer recording

final class ScreenNameObserverRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValues: [String] = []

    var values: [String] {
        lock.withLock { storedValues }
    }

    var last: String? {
        lock.withLock { storedValues.last }
    }

    func append(_ value: String) {
        lock.withLock { storedValues.append(value) }
    }
}
