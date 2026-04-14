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
import SplunkCommon

@testable import SplunkNavigation

struct MockNavigationActionEvent: NavigationActionEvent {
    let timestamp: Date
    let type: NavigationActionEventType
    let navigationControllerIdentifier: ObjectIdentifier?
    let controllerTypeName: String
    let controllerIdentifier: ObjectIdentifier
    var viewFrame: CGRect?
}

struct EmptyNavigationEventStreamProvider: NavigationEventStreamProviding {
    func navigationStream() async throws -> AsyncStream<any NavigationActionEvent> {
        await Task.yield()
        return AsyncStream<any NavigationActionEvent> { _ in }
    }
}

struct MockNavigationEventStreamProvider: NavigationEventStreamProviding {
    let stream: AsyncStream<any NavigationActionEvent>

    func navigationStream() async throws -> AsyncStream<any NavigationActionEvent> {
        await Task.yield()
        return stream
    }
}

actor ScreenNameCollector {
    private(set) var values: [String] = []

    func append(_ value: String) {
        values.append(value)
    }
}

struct NavigationStreamFixture {
    let navigation: Navigation
    let continuation: AsyncStream<any NavigationActionEvent>.Continuation
    let collector: ScreenNameCollector
    let collectionTask: Task<Void, Never>

    func finish() {
        continuation.finish()
        collectionTask.cancel()
    }
}

func makeNavigationStreamFixture() -> NavigationStreamFixture {
    let (stream, continuation) = AsyncStream.makeStream(
        of: (any NavigationActionEvent).self
    )

    let navigation = Navigation(
        navigationEventStreamProvider: MockNavigationEventStreamProvider(
            stream: stream
        )
    )

    let collector = ScreenNameCollector()
    let collectionTask = Task { [weak navigation] in
        guard let navigation else {
            return
        }

        for await screenName in navigation.screenNameStream {
            await collector.append(screenName)
        }
    }

    return NavigationStreamFixture(
        navigation: navigation,
        continuation: continuation,
        collector: collector,
        collectionTask: collectionTask
    )
}

func sendTransition(
    type: NavigationActionEventType,
    fixture: NavigationStreamFixture,
    navigationControllerIdentifier: ObjectIdentifier,
    controllerIdentifier: ObjectIdentifier,
    controllerTypeName: String
) {
    fixture.continuation.yield(
        makeTransitionEvent(
            type: type,
            navigationControllerIdentifier: navigationControllerIdentifier,
            controllerIdentifier: controllerIdentifier,
            controllerTypeName: controllerTypeName
        )
    )
}

func sendManagedLifecycleEvents(
    fixture: NavigationStreamFixture,
    controllerIdentifier: ObjectIdentifier,
    controllerTypeName: String
) {
    fixture.continuation.yield(
        AutomatedNavigationEvent(
            timestamp: Date(),
            type: .viewDidLoad,
            controllerTypeName: controllerTypeName,
            controllerIdentifier: controllerIdentifier
        )
    )
    fixture.continuation.yield(
        AutomatedNavigationEvent(
            timestamp: Date(),
            type: .viewDidAppear,
            controllerTypeName: controllerTypeName,
            controllerIdentifier: controllerIdentifier
        )
    )
}

func showController(
    fixture: NavigationStreamFixture,
    navigationControllerIdentifier: ObjectIdentifier,
    controllerIdentifier: ObjectIdentifier,
    controllerTypeName: String
) {
    sendTransition(
        type: .navigationControllerWillShow,
        fixture: fixture,
        navigationControllerIdentifier: navigationControllerIdentifier,
        controllerIdentifier: controllerIdentifier,
        controllerTypeName: controllerTypeName
    )
    sendTransition(
        type: .navigationControllerDidShow,
        fixture: fixture,
        navigationControllerIdentifier: navigationControllerIdentifier,
        controllerIdentifier: controllerIdentifier,
        controllerTypeName: controllerTypeName
    )
}

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
