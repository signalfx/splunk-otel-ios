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
import OpenTelemetryApi
import OpenTelemetrySdk
@_spi(SplunkTesting) import SplunkCommon
@_spi(SplunkTesting) import SplunkNavigation
import XCTest

@testable import SplunkNavigation

private let reservedAttributeDedupeEvents = [
    NavigationEvent(
        name: "SharedScreen",
        attributes: [
            "component": "hacker1",
            "screen.name": "hacker1",
            "step": "same"
        ]
    ),
    NavigationEvent(
        name: "SharedScreen",
        attributes: [
            "component": "hacker2",
            "screen.name": "hacker2",
            "step": "same"
        ]
    )
]

final class NavigationAutomatedAttributeDedupeTests: XCTestCase {

    private var exporter = CollectingSpanExporter()
    private var originalTracerProvider: TracerProvider = OpenTelemetry.instance.tracerProvider

    override func setUp() {
        super.setUp()

        exporter = CollectingSpanExporter()
        let tracerProvider = TracerProviderBuilder()
            .add(spanProcessor: SimpleSpanProcessor(spanExporter: exporter))
            .build()
        OpenTelemetry.registerTracerProvider(tracerProvider: tracerProvider)
    }

    override func tearDown() {
        OpenTelemetry.registerTracerProvider(tracerProvider: originalTracerProvider)
        super.tearDown()
    }

    func testAutomatedSameNameNavigationEmitsWhenAttributesChange() async {
        let fixture = makeNavigationStreamFixture(
            navigationEventProcessor: SequenceNavigationEventProcessor(
                events: [
                    NavigationEvent(name: "SharedScreen", attributes: ["step": "first"]),
                    NavigationEvent(name: "SharedScreen", attributes: ["step": "second"])
                ]
            )
        )
        defer {
            fixture.finish()
        }

        let navigation = fixture.navigation
        navigation.preferences.enableAutomatedTracking = true
        navigation.startDetection()

        let navigationController = NSString()
        let firstController = NSString()
        let secondController = NSString()
        let navigationControllerIdentifier = ObjectIdentifier(navigationController)

        fixture.showController(
            navigationControllerIdentifier: navigationControllerIdentifier,
            controllerIdentifier: ObjectIdentifier(firstController),
            controllerTypeName: "GenericViewController"
        )
        await waitUntil {
            self.navigationSpans.count >= 1
        }

        fixture.showController(
            navigationControllerIdentifier: navigationControllerIdentifier,
            controllerIdentifier: ObjectIdentifier(secondController),
            controllerTypeName: "GenericViewController"
        )
        await waitUntil {
            self.navigationSpans.count >= 2
        }

        let spans = navigationSpans
        XCTAssertEqual(spans.count, 2)
        XCTAssertEqual(spans[0].attributes["screen.name"]?.description, "SharedScreen")
        XCTAssertEqual(spans[0].attributes["step"]?.description, "first")
        XCTAssertEqual(spans[1].attributes["screen.name"]?.description, "SharedScreen")
        XCTAssertEqual(spans[1].attributes["step"]?.description, "second")
    }

    func testAutomatedSameNameNavigationSuppressesWhenAttributesMatch() async {
        let fixture = makeNavigationStreamFixture(
            navigationEventProcessor: SequenceNavigationEventProcessor(
                events: [
                    NavigationEvent(name: "SharedScreen", attributes: ["step": "same"]),
                    NavigationEvent(name: "SharedScreen", attributes: ["step": "same"])
                ]
            )
        )
        defer {
            fixture.finish()
        }

        let navigation = fixture.navigation
        navigation.preferences.enableAutomatedTracking = true
        navigation.startDetection()

        let navigationController = NSString()
        let firstController = NSString()
        let secondController = NSString()
        let navigationControllerIdentifier = ObjectIdentifier(navigationController)

        fixture.showController(
            navigationControllerIdentifier: navigationControllerIdentifier,
            controllerIdentifier: ObjectIdentifier(firstController),
            controllerTypeName: "GenericViewController"
        )
        await waitUntil {
            self.navigationSpans.count >= 1
        }

        fixture.showController(
            navigationControllerIdentifier: navigationControllerIdentifier,
            controllerIdentifier: ObjectIdentifier(secondController),
            controllerTypeName: "GenericViewController"
        )

        try? await Task.sleep(nanoseconds: 200_000_000)

        let spans = navigationSpans
        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual(spans[0].attributes["screen.name"]?.description, "SharedScreen")
        XCTAssertEqual(spans[0].attributes["step"]?.description, "same")
    }

    func testAutomatedSameNameNavigationIgnoresReservedAttributeChangesForDedupe() async {
        let fixture = makeNavigationStreamFixture(
            navigationEventProcessor: SequenceNavigationEventProcessor(
                events: reservedAttributeDedupeEvents
            )
        )
        defer {
            fixture.finish()
        }

        let navigation = fixture.navigation
        navigation.preferences.enableAutomatedTracking = true
        navigation.startDetection()

        let navigationController = NSString()
        let firstController = NSString()
        let secondController = NSString()
        let navigationControllerIdentifier = ObjectIdentifier(navigationController)

        fixture.showController(
            navigationControllerIdentifier: navigationControllerIdentifier,
            controllerIdentifier: ObjectIdentifier(firstController),
            controllerTypeName: "GenericViewController"
        )
        await waitUntil {
            self.navigationSpans.count >= 1
        }

        fixture.showController(
            navigationControllerIdentifier: navigationControllerIdentifier,
            controllerIdentifier: ObjectIdentifier(secondController),
            controllerTypeName: "GenericViewController"
        )

        try? await Task.sleep(nanoseconds: 200_000_000)

        let spans = navigationSpans
        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual(spans[0].attributes["screen.name"]?.description, "SharedScreen")
        XCTAssertEqual(spans[0].attributes["component"]?.description, "ui")
        XCTAssertEqual(spans[0].attributes["step"]?.description, "same")
    }

    func testManualTrackUpdatesAutomatedDedupeState() async {
        let fixture = makeNavigationStreamFixture(
            navigationEventProcessor: SequenceNavigationEventProcessor(
                events: [
                    NavigationEvent(name: "HomeScreen", attributes: ["step": "manual"])
                ]
            )
        )
        defer {
            fixture.finish()
        }

        let navigation = fixture.navigation
        navigation.preferences.enableAutomatedTracking = true
        navigation.startDetection()

        navigation.track(screen: "HomeScreen", attributes: ["step": "manual"])
        await waitUntil {
            self.navigationSpans.count >= 1
        }

        let navigationController = NSString()
        let controller = NSString()

        fixture.showController(
            navigationControllerIdentifier: ObjectIdentifier(navigationController),
            controllerIdentifier: ObjectIdentifier(controller),
            controllerTypeName: "GenericViewController"
        )

        try? await Task.sleep(nanoseconds: 200_000_000)

        let spans = navigationSpans
        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual(spans[0].attributes["screen.name"]?.description, "HomeScreen")
        XCTAssertEqual(spans[0].attributes["step"]?.description, "manual")
    }

    private var navigationSpans: [SpanData] {
        exporter.spans.filter { $0.name == "app.ui.navigation" }
    }
}
