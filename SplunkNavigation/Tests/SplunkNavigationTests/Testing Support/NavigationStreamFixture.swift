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
@_spi(SplunkTesting) import SplunkNavigation

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


// MARK: - Fixture construction

func makeNavigationStreamFixture(
    navigationEventProcessor: any NavigationEventProcessor = DefaultNavigationEventProcessor()
) -> NavigationStreamFixture {
    let (stream, continuation) = AsyncStream.makeStream(
        of: (any NavigationActionEvent).self
    )

    let navigation = Navigation(
        navigationEventStreamProvider: MockNavigationEventStreamProvider(
            stream: stream
        ),
        navigationEventProcessor: navigationEventProcessor
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


// MARK: - Fixture actions

extension NavigationStreamFixture {

    func sendTransition(
        type: NavigationActionEventType,
        navigationControllerIdentifier: ObjectIdentifier,
        controllerIdentifier: ObjectIdentifier,
        controllerTypeName: String
    ) {
        continuation.yield(
            makeTransitionEvent(
                type: type,
                navigationControllerIdentifier: navigationControllerIdentifier,
                controllerIdentifier: controllerIdentifier,
                controllerTypeName: controllerTypeName
            )
        )
    }

    func sendManagedLifecycleEvents(
        controllerIdentifier: ObjectIdentifier,
        controllerTypeName: String
    ) {
        continuation.yield(
            AutomatedNavigationEvent(
                timestamp: Date(),
                type: .viewDidLoad,
                controllerTypeName: controllerTypeName,
                controllerIdentifier: controllerIdentifier
            )
        )
        continuation.yield(
            AutomatedNavigationEvent(
                timestamp: Date(),
                type: .viewDidAppear,
                controllerTypeName: controllerTypeName,
                controllerIdentifier: controllerIdentifier
            )
        )
    }

    func showController(
        navigationControllerIdentifier: ObjectIdentifier,
        controllerIdentifier: ObjectIdentifier,
        controllerTypeName: String
    ) {
        sendTransition(
            type: .navigationControllerWillShow,
            navigationControllerIdentifier: navigationControllerIdentifier,
            controllerIdentifier: controllerIdentifier,
            controllerTypeName: controllerTypeName
        )
        sendTransition(
            type: .navigationControllerDidShow,
            navigationControllerIdentifier: navigationControllerIdentifier,
            controllerIdentifier: controllerIdentifier,
            controllerTypeName: controllerTypeName
        )
    }
}
