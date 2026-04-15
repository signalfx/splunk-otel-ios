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
@_spi(SplunkTesting) import SplunkCommon
import XCTest

@testable import SplunkNavigation

final class NavigationEventProcessorTests: XCTestCase {

    // MARK: - Default processor

    func testDefaultProcessorPassesScreenNameThrough() async {
        let detailIdentifier = ObjectIdentifier(NSString())
        let navigationControllerIdentifier = ObjectIdentifier(NSNumber(value: 1))

        let events = makeEventStream([
            makeTransitionEvent(
                type: .navigationControllerWillShow,
                navigationControllerIdentifier: navigationControllerIdentifier,
                controllerIdentifier: detailIdentifier,
                controllerTypeName: "DetailViewController"
            ),
            makeTransitionEvent(
                type: .navigationControllerDidShow,
                navigationControllerIdentifier: navigationControllerIdentifier,
                controllerIdentifier: detailIdentifier,
                controllerTypeName: "DetailViewController"
            )
        ])

        let navigation = Navigation(
            navigationEventStreamProvider: MockNavigationEventStreamProvider(stream: events)
        )
        navigation.preferences.enableAutomatedTracking = true
        navigation.startDetection()

        let didUpdate = await waitUntil {
            await navigation.model.screenName == "DetailViewController"
        }
        XCTAssertTrue(didUpdate)
    }

    // MARK: - Custom processor

    func testCustomProcessorTransformsScreenName() async {
        let detailIdentifier = ObjectIdentifier(NSString())
        let navigationControllerIdentifier = ObjectIdentifier(NSNumber(value: 2))

        let events = makeEventStream([
            makeTransitionEvent(
                type: .navigationControllerWillShow,
                navigationControllerIdentifier: navigationControllerIdentifier,
                controllerIdentifier: detailIdentifier,
                controllerTypeName: "DetailViewController"
            ),
            makeTransitionEvent(
                type: .navigationControllerDidShow,
                navigationControllerIdentifier: navigationControllerIdentifier,
                controllerIdentifier: detailIdentifier,
                controllerTypeName: "DetailViewController"
            )
        ])

        let navigation = Navigation(
            navigationEventStreamProvider: MockNavigationEventStreamProvider(stream: events)
        )
        navigation.navigationEventProcessor = PrefixingProcessor(prefix: "Custom")
        navigation.preferences.enableAutomatedTracking = true
        navigation.startDetection()

        let didUpdate = await waitUntil {
            await navigation.model.screenName == "Custom/DetailViewController"
        }
        XCTAssertTrue(didUpdate)
    }

    // MARK: - Manual tracking bypass

    func testManualTrackBypassesProcessor() async {
        let fixture = makeNavigationStreamFixture()

        defer {
            fixture.finish()
        }

        let navigation = fixture.navigation
        navigation.navigationEventProcessor = RejectingProcessor()
        navigation.preferences.enableAutomatedTracking = true

        navigation.startDetection()

        navigation.track(screen: "ManualScreen")

        let didUpdate = await waitUntil {
            await navigation.model.screenName == "ManualScreen"
        }
        XCTAssertTrue(didUpdate)
    }

    func testProcessorAppliesToAutomatedButNotManual() async {
        let fixture = makeNavigationStreamFixture()

        defer {
            fixture.finish()
        }

        let navigation = fixture.navigation
        navigation.navigationEventProcessor = PrefixingProcessor(prefix: "Auto")
        navigation.preferences.enableAutomatedTracking = true

        navigation.startDetection()

        navigation.track(screen: "ManualScreen")

        let didSetManual = await waitUntil {
            await navigation.model.screenName == "ManualScreen"
        }
        XCTAssertTrue(didSetManual)

        let detailIdentifier = ObjectIdentifier(NSString())
        let navigationControllerIdentifier = ObjectIdentifier(NSNumber(value: 3))

        fixture.sendTransition(
            type: .navigationControllerWillShow,
            navigationControllerIdentifier: navigationControllerIdentifier,
            controllerIdentifier: detailIdentifier,
            controllerTypeName: "DetailViewController"
        )
        fixture.sendTransition(
            type: .navigationControllerDidShow,
            navigationControllerIdentifier: navigationControllerIdentifier,
            controllerIdentifier: detailIdentifier,
            controllerTypeName: "DetailViewController"
        )

        let didSetAuto = await waitUntil {
            await navigation.model.screenName == "Auto/DetailViewController"
        }
        XCTAssertTrue(didSetAuto)
    }
}


// MARK: - Test processors

private final class PrefixingProcessor: NSObject, NavigationEventProcessor {
    let prefix: String

    init(prefix: String) {
        self.prefix = prefix
    }

    func process(event: NavigationEvent) -> NavigationEvent {
        NavigationEvent(
            screenName: "\(prefix)/\(event.screenName)",
            controllerIdentifier: event.controllerIdentifier,
            attributes: event.attributes
        )
    }
}

private final class RejectingProcessor: NSObject, NavigationEventProcessor {
    func process(event: NavigationEvent) -> NavigationEvent {
        NavigationEvent(
            screenName: "REJECTED",
            controllerIdentifier: event.controllerIdentifier
        )
    }
}
