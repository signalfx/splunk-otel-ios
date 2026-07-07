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
import UIKit

@testable import SplunkNavigation

/// A test double that drives both the navigation stream and the presentation
/// stream, used when the race between the two detection loops must be exercised.
final class MockCombinedEventStreamProvider: NavigationEventStreamProviding {

    private let navigationContinuation: AsyncStream<any NavigationActionEvent>.Continuation
    private let presentationContinuation: AsyncStream<any PresentationActionEvent>.Continuation
    private let internalNavigationStream: AsyncStream<any NavigationActionEvent>
    private let internalPresentationStream: AsyncStream<any PresentationActionEvent>
    private let presentationControllerProxy = PresentationControllerProxy()

    init() {
        let (navStream, navContinuation) = AsyncStream.makeStream(
            of: (any NavigationActionEvent).self
        )
        let (presStream, presContinuation) = AsyncStream.makeStream(
            of: (any PresentationActionEvent).self
        )
        internalNavigationStream = navStream
        navigationContinuation = navContinuation
        internalPresentationStream = presStream
        presentationContinuation = presContinuation
    }

    func navigationStream() async throws -> AsyncStream<any NavigationActionEvent> {
        await Task.yield()
        return internalNavigationStream
    }

    func presentationStream() async throws -> AsyncStream<any PresentationActionEvent> {
        await Task.yield()
        return internalPresentationStream
    }

    func emitNavigation(
        type: NavigationActionEventType,
        controller: UIViewController,
        timestamp: Date = Date()
    ) {
        navigationContinuation.yield(
            AutomatedNavigationEvent(
                timestamp: timestamp,
                type: type,
                controllerTypeName: String(describing: Swift.type(of: controller)),
                controllerIdentifier: ObjectIdentifier(controller)
            )
        )
    }

    func emitPresentation(
        eventType: PresentationActionEventType,
        presented: UIViewController,
        presenting: UIViewController,
        completed: Bool?,
        timestamp: Date = Date()
    ) {
        let event = MockPresentationActionEvent(
            timestamp: timestamp,
            type: eventType,
            presentationControllerIdentifier: ObjectIdentifier(presentationControllerProxy),
            presentedControllerTypeName: String(describing: Swift.type(of: presented)),
            presentedControllerIdentifier: ObjectIdentifier(presented),
            presentingControllerTypeName: String(describing: Swift.type(of: presenting)),
            presentingControllerIdentifier: ObjectIdentifier(presenting),
            completed: completed
        )
        presentationContinuation.yield(event)
    }
}

private final class PresentationControllerProxy: Sendable {}
