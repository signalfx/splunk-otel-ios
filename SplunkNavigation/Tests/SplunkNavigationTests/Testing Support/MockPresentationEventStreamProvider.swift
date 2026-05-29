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

struct MockPresentationActionEvent: PresentationActionEvent {
    let timestamp: Date
    let type: PresentationActionEventType
    let presentationControllerIdentifier: ObjectIdentifier
    let presentedControllerTypeName: String
    let presentedControllerIdentifier: ObjectIdentifier
    let presentingControllerTypeName: String
    let presentingControllerIdentifier: ObjectIdentifier
    let completed: Bool?
}

private final class PresentationControllerProxy: Sendable {}

final class MockPresentationEventStreamProvider:
    NavigationEventStreamProviding
{
    private let presentationContinuation: AsyncStream<any PresentationActionEvent>.Continuation
    private let internalPresentationStream: AsyncStream<any PresentationActionEvent>
    private let presentationControllerProxy = PresentationControllerProxy()

    init() {
        let (stream, continuation) = AsyncStream.makeStream(
            of: (any PresentationActionEvent).self
        )
        internalPresentationStream = stream
        presentationContinuation = continuation
    }

    func navigationStream() async throws -> AsyncStream<any NavigationActionEvent> {
        await Task.yield()
        return AsyncStream { _ in }
    }

    func presentationStream() async throws -> AsyncStream<any PresentationActionEvent> {
        await Task.yield()
        return internalPresentationStream
    }

    func emit(
        eventType: PresentationActionEventType,
        presented: UIViewController,
        presenting: UIViewController,
        completed: Bool?
    ) {
        let event = MockPresentationActionEvent(
            timestamp: Date(),
            type: eventType,
            presentationControllerIdentifier: ObjectIdentifier(presentationControllerProxy),
            presentedControllerTypeName: String(describing: type(of: presented)),
            presentedControllerIdentifier: ObjectIdentifier(presented),
            presentingControllerTypeName: String(describing: type(of: presenting)),
            presentingControllerIdentifier: ObjectIdentifier(presenting),
            completed: completed
        )

        presentationContinuation.yield(event)
    }
}
