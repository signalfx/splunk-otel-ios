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
@_spi(SplunkTesting) import SplunkCommon
@_spi(SplunkTesting) import SplunkNavigation
import UIKit
import XCTest

final class NavigationPresentationTimestampTests: XCTestCase {

    // MARK: - Timestamp preservation

    @MainActor
    func testPresentationStartUsesEventTimestamp() async {
        let presentingController = PresentingViewController()
        let presentedController = PresentedViewController()

        let provider = MockPresentationEventStreamProvider()
        let module = Navigation(navigationEventStreamProvider: provider)
        module.preferences.enableAutomatedTracking = true
        module.startDetection()

        let eventTimestamp = Date(timeIntervalSinceNow: -1)

        provider.emit(
            eventType: .presentationWillBegin,
            presented: presentedController,
            presenting: presentingController,
            completed: nil,
            timestamp: eventTimestamp
        )

        let controllerIdentifier = ObjectIdentifier(presentedController)
        let didStoreNavigation = await waitUntil {
            await module.model.navigation(for: controllerIdentifier) != nil
        }
        XCTAssertTrue(didStoreNavigation)

        let start = await module.model.navigation(for: controllerIdentifier)?.start
        XCTAssertEqual(start, eventTimestamp)
    }
}
