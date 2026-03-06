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
import XCTest

@testable import SplunkNavigation

final class NavigationEventSourcesTests: XCTestCase {

    // MARK: - Seams

    func testModernNavigationStream_UsesInjectedProvider() async throws {
        let expectedName = "MockViewController"
        let expectedEvent = AutomatedNavigationEvent(
            timestamp: Date(),
            type: .viewDidAppear,
            controllerTypeName: expectedName,
            controllerIdentifier: ObjectIdentifier(NSString())
        )

        let navigation = Navigation(
            navigationEventStreamProvider: MockNavigationEventStreamProvider(
                stream: makeStream([expectedEvent])
            )
        )

        let stream = try await navigation.modernNavigationStream()
        var iterator = stream.makeAsyncIterator()
        let firstEvent = await iterator.next()

        XCTAssertEqual(firstEvent?.controllerTypeName, expectedName)
    }

    func testDefaultProviders_RemainProductionImplementations() {
        let navigation = Navigation()

        XCTAssertTrue(type(of: navigation.navigationEventStreamProvider) == DefaultNavigationEventStreamProvider.self)
    }

    // MARK: - Filtering scaffold

    func testShouldIgnore_ReturnsTrueForKnownInternalControllers() {
        let navigation = Navigation()

        XCTAssertTrue(navigation.shouldIgnore(controllerTypeName: "UINavigationController"))
        XCTAssertTrue(navigation.shouldIgnore(controllerTypeName: "UITabBarController"))
    }

    func testShouldIgnore_ReturnsFalseForRegularControllerName() {
        let navigation = Navigation()

        XCTAssertFalse(navigation.shouldIgnore(controllerTypeName: "ProductDetailsViewController"))
    }
}

private struct MockNavigationEventStreamProvider: NavigationEventStreamProviding {
    let stream: AsyncStream<any NavigationActionEvent>

    func navigationStream() async throws -> AsyncStream<any NavigationActionEvent> {
        await Task.yield()
        return stream
    }
}

private func makeStream<T>(_ values: [T]) -> AsyncStream<T> {
    AsyncStream { continuation in
        for value in values {
            continuation.yield(value)
        }
        continuation.finish()
    }
}
