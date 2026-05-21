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

// swiftformat:disable sortImports
import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk
@_spi(SplunkTesting) import SplunkCommon
@_spi(SplunkInternal) @testable import SplunkNavigation
import XCTest

final class NavigationTimingSpanAttributesTests: XCTestCase {

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

    private var showVCSpans: [SpanData] {
        exporter.spans.filter { $0.name == "ShowVC" }
    }
}
