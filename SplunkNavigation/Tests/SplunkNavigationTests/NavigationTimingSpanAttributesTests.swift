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
import UIKit
import XCTest
@testable import SplunkNavigation // swiftlint:disable:this sorted_imports

final class NavigationTimingSpanAttributesTests: XCTestCase {

    // MARK: - Private

    private var exporter = CollectingSpanExporter()
    private var originalTracerProvider: TracerProvider = OpenTelemetry.instance.tracerProvider


    // MARK: - Tests lifecycle

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

    // MARK: - Tests

    func testShowVCSpanCarriesLastScreenName() async {
        let fixture = makeNavigationStreamFixture()
        defer { fixture.finish() }

        let navigation = fixture.navigation
        navigation.preferences.enableAutomatedTracking = true
        navigation.startDetection()

        let navController = NSString()
        let firstController = NSString()
        let secondController = NSString()
        let navControllerIdentifier = ObjectIdentifier(navController)

        fixture.showController(
            navigationControllerIdentifier: navControllerIdentifier,
            controllerIdentifier: ObjectIdentifier(firstController),
            controllerTypeName: "HomeViewController"
        )
        await waitUntil {
            self.showVCSpans.count >= 1
        }

        fixture.showController(
            navigationControllerIdentifier: navControllerIdentifier,
            controllerIdentifier: ObjectIdentifier(secondController),
            controllerTypeName: "DetailViewController"
        )
        await waitUntil {
            self.showVCSpans.count >= 2
        }

        let spans = showVCSpans
        XCTAssertEqual(spans.count, 2)
        XCTAssertEqual(spans[0].attributes["screen.name"]?.description, "HomeViewController")
        XCTAssertNil(spans[0].attributes["last.screen.name"], "First ShowVC should not emit last.screen.name")
        XCTAssertEqual(spans[1].attributes["screen.name"]?.description, "DetailViewController")
        XCTAssertEqual(spans[1].attributes["last.screen.name"]?.description, "HomeViewController")
    }

    func testPresentationTransitionSpanCarriesLastScreenName() async {
        let presentingController = UIViewController()
        let presentedController = UIViewController()

        let provider = MockPresentationEventStreamProvider()
        let navigation = Navigation(navigationEventStreamProvider: provider)
        navigation.preferences.enableAutomatedTracking = true
        navigation.startDetection()

        navigation.track(screen: "HomeViewController")

        provider.emit(
            eventType: .presentationWillBegin,
            presented: presentedController,
            presenting: presentingController,
            completed: nil
        )
        provider.emit(
            eventType: .presentationDidEnd,
            presented: presentedController,
            presenting: presentingController,
            completed: true
        )

        await waitUntil {
            self.presentationTransitionSpans.count >= 1
        }

        let spans = presentationTransitionSpans
        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual(
            spans[0].attributes["last.screen.name"]?.description,
            "HomeViewController"
        )
    }

    // MARK: - Helpers

    private var showVCSpans: [SpanData] {
        exporter.spans.filter { $0.name == "ShowVC" }
    }

    private var presentationTransitionSpans: [SpanData] {
        exporter.spans.filter { $0.name == "PresentationTransition" }
    }
}
