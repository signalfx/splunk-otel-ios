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

import OpenTelemetryApi
import OpenTelemetrySdk
@_spi(SplunkTesting) import SplunkCommon
import XCTest

@testable import SplunkNavigation

// MARK: - Span-collecting exporter

private final class CollectingSpanExporter: SpanExporter {
    private let lock = NSLock()
    private var collected: [SpanData] = []

    var spans: [SpanData] {
        lock.withLock { collected }
    }

    func reset() {
        lock.withLock { collected.removeAll() }
    }

    func export(spans: [SpanData], explicitTimeout _: TimeInterval?) -> SpanExporterResultCode {
        lock.withLock { collected.append(contentsOf: spans) }
        return .success
    }

    func flush(explicitTimeout _: TimeInterval?) -> SpanExporterResultCode {
        .success
    }

    func shutdown(explicitTimeout _: TimeInterval?) {}
}

// MARK: - Tests

final class NavigationTrackScreenAttributesTests: XCTestCase {

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

    func testTrackScreenAttributesForwardedToSpan() async {
        let module = Navigation()
        module.preferences = Preferences(enableAutomatedTracking: false)

        module.track(screen: "HomeScreen", attributes: ["section": "main", "tab": "dashboard"])

        await waitUntil {
            await module.model.screenName == "HomeScreen"
        }

        await waitUntil {
            self.exporter.spans.contains { $0.name == "app.ui.navigation" }
        }

        let span = exporter.spans.first { $0.name == "app.ui.navigation" }
        XCTAssertNotNil(span, "Expected an app.ui.navigation span")
        XCTAssertEqual(span?.attributes["screen.name"]?.description, "HomeScreen")
        XCTAssertEqual(span?.attributes["section"]?.description, "main")
        XCTAssertEqual(span?.attributes["tab"]?.description, "dashboard")
    }
}
