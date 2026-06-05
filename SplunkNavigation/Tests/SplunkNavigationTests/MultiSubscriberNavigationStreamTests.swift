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
import XCTest

final class MultiSubscriberNavigationStreamTests: XCTestCase {

    // MARK: - Navigation streams

    func testIndependentProvidersReceiveSameNavigationEvents() async throws {
        let source = BroadcastNavigationEventSource()
        let firstProvider = BroadcastNavigationEventStreamProvider(source: source)
        let secondProvider = BroadcastNavigationEventStreamProvider(source: source)

        let firstStream = try await firstProvider.navigationStream()
        let secondStream = try await secondProvider.navigationStream()

        let firstTask = Task {
            await collectNavigationEvents(from: firstStream, count: 2)
        }
        let secondTask = Task {
            await collectNavigationEvents(from: secondStream, count: 2)
        }

        await source.yieldNavigation(
            BroadcastMockNavigationActionEvent(
                timestamp: Date(),
                type: .viewDidLoad,
                navigationControllerIdentifier: nil,
                controllerTypeName: "FirstViewController",
                controllerIdentifier: ObjectIdentifier(NSObject())
            )
        )
        await source.yieldNavigation(
            BroadcastMockNavigationActionEvent(
                timestamp: Date(),
                type: .viewDidAppear,
                navigationControllerIdentifier: nil,
                controllerTypeName: "FirstViewController",
                controllerIdentifier: ObjectIdentifier(NSObject())
            )
        )

        let firstEvents = await firstTask.value
        let secondEvents = await secondTask.value

        XCTAssertEqual(
            firstEvents,
            [
                "viewDidLoad:FirstViewController",
                "viewDidAppear:FirstViewController"
            ]
        )
        XCTAssertEqual(secondEvents, firstEvents)
    }

    // MARK: - Presentation streams

    func testIndependentProvidersReceiveSamePresentationEvents() async throws {
        let source = BroadcastNavigationEventSource()
        let firstProvider = BroadcastNavigationEventStreamProvider(source: source)
        let secondProvider = BroadcastNavigationEventStreamProvider(source: source)

        let firstStream = try await firstProvider.presentationStream()
        let secondStream = try await secondProvider.presentationStream()

        let firstTask = Task {
            await collectPresentationEvents(from: firstStream, count: 2)
        }
        let secondTask = Task {
            await collectPresentationEvents(from: secondStream, count: 2)
        }

        await source.yieldPresentation(
            BroadcastMockPresentationActionEvent(
                timestamp: Date(),
                type: .presentationWillBegin,
                presentationControllerIdentifier: ObjectIdentifier(NSObject()),
                presentedControllerTypeName: "PresentedViewController",
                presentedControllerIdentifier: ObjectIdentifier(NSObject()),
                presentingControllerTypeName: "PresentingViewController",
                presentingControllerIdentifier: ObjectIdentifier(NSObject()),
                completed: nil
            )
        )
        await source.yieldPresentation(
            BroadcastMockPresentationActionEvent(
                timestamp: Date(),
                type: .presentationDidEnd,
                presentationControllerIdentifier: ObjectIdentifier(NSObject()),
                presentedControllerTypeName: "PresentedViewController",
                presentedControllerIdentifier: ObjectIdentifier(NSObject()),
                presentingControllerTypeName: "PresentingViewController",
                presentingControllerIdentifier: ObjectIdentifier(NSObject()),
                completed: true
            )
        )

        let firstEvents = await firstTask.value
        let secondEvents = await secondTask.value

        XCTAssertEqual(
            firstEvents,
            [
                "presentationWillBegin:PresentedViewController",
                "presentationDidEnd:PresentedViewController"
            ]
        )
        XCTAssertEqual(secondEvents, firstEvents)
    }
}

// MARK: - Test provider

private struct BroadcastNavigationEventStreamProvider: NavigationEventStreamProviding {
    let source: BroadcastNavigationEventSource

    func navigationStream() async throws -> AsyncStream<any NavigationActionEvent> {
        await source.makeNavigationStream()
    }

    func presentationStream() async throws -> AsyncStream<any PresentationActionEvent> {
        await source.makePresentationStream()
    }
}

private actor BroadcastNavigationEventSource {
    private var navigationContinuations: [AsyncStream<any NavigationActionEvent>.Continuation] = []
    private var presentationContinuations: [AsyncStream<any PresentationActionEvent>.Continuation] = []

    func makeNavigationStream() -> AsyncStream<any NavigationActionEvent> {
        let (stream, continuation) = AsyncStream.makeStream(
            of: (any NavigationActionEvent).self
        )
        navigationContinuations.append(continuation)

        return stream
    }

    func makePresentationStream() -> AsyncStream<any PresentationActionEvent> {
        let (stream, continuation) = AsyncStream.makeStream(
            of: (any PresentationActionEvent).self
        )
        presentationContinuations.append(continuation)

        return stream
    }

    func yieldNavigation(_ event: any NavigationActionEvent) {
        for continuation in navigationContinuations {
            continuation.yield(event)
        }
    }

    func yieldPresentation(_ event: any PresentationActionEvent) {
        for continuation in presentationContinuations {
            continuation.yield(event)
        }
    }
}

// MARK: - Test events

private struct BroadcastMockNavigationActionEvent: NavigationActionEvent {
    let timestamp: Date
    let type: NavigationActionEventType
    let navigationControllerIdentifier: ObjectIdentifier?
    let controllerTypeName: String
    let controllerIdentifier: ObjectIdentifier
    var viewFrame: CGRect?
}

private struct BroadcastMockPresentationActionEvent: PresentationActionEvent {
    let timestamp: Date
    let type: PresentationActionEventType
    let presentationControllerIdentifier: ObjectIdentifier
    let presentedControllerTypeName: String
    let presentedControllerIdentifier: ObjectIdentifier
    let presentingControllerTypeName: String
    let presentingControllerIdentifier: ObjectIdentifier
    let completed: Bool?
}


// MARK: - Collection

private func collectNavigationEvents(
    from stream: AsyncStream<any NavigationActionEvent>,
    count: Int
) async -> [String] {
    var events: [String] = []
    for await event in stream {
        events.append("\(event.type):\(event.controllerTypeName)")
        if events.count == count {
            break
        }
    }

    return events
}

private func collectPresentationEvents(
    from stream: AsyncStream<any PresentationActionEvent>,
    count: Int
) async -> [String] {
    var events: [String] = []
    for await event in stream {
        events.append("\(event.type):\(event.presentedControllerTypeName)")
        if events.count == count {
            break
        }
    }

    return events
}
