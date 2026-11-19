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
import XCTest

@testable import SplunkAppStart

/// Covers the install span that App Start sends as a child of a cold `AppStart` span.
final class InstallSpanTests: XCTestCase {

    // MARK: - Private

    private let processStart = Date(timeIntervalSinceReferenceDate: 6_000)
    private let exporter = InstallSpanRecordingExporter()
    private lazy var tracerProvider = TracerProviderBuilder()
        .add(spanProcessor: SimpleSpanProcessor(spanExporter: exporter))
        .build()
    private var originalTracerProvider: TracerProvider = OpenTelemetry.instance.tracerProvider

    private var installStart: Date {
        processStart.addingTimeInterval(0.2)
    }

    private var installEvent: Date {
        processStart.addingTimeInterval(0.3)
    }

    private var installEnd: Date {
        processStart.addingTimeInterval(0.4)
    }


    // MARK: - Tests lifecycle

    override func setUp() {
        super.setUp()

        originalTracerProvider = OpenTelemetry.instance.tracerProvider
        OpenTelemetry.registerTracerProvider(tracerProvider: tracerProvider)
    }

    override func tearDown() {
        OpenTelemetry.registerTracerProvider(tracerProvider: originalTracerProvider)

        super.tearDown()
    }


    // MARK: - Tests

    func testColdStartSendsInstallSpanAsChildOfAppStart() throws {
        let spans = sendColdStartWithInstallData()

        let appStartSpan = try XCTUnwrap(spans.first { $0.name == "AppStart" })
        let installSpans = spans.filter { $0.name == "SplunkRum.install" }
        XCTAssertEqual(installSpans.count, 1)
        let installSpan = try XCTUnwrap(installSpans.first)

        XCTAssertEqual(installSpan.parentSpanId, appStartSpan.spanId)
        XCTAssertEqual(installSpan.traceId, appStartSpan.traceId)
        XCTAssertEqual(installSpan.instrumentationScope.name, "splunk-app-start")
        XCTAssertEqual(installSpan.startTime, installStart)
        XCTAssertEqual(installSpan.endTime, installEnd)
        XCTAssertEqual(installSpan.attributes["component"], AttributeValue.string("appstart"))
        XCTAssertEqual(installSpan.attributes["screen.name"], AttributeValue.string("unknown"))
        XCTAssertEqual(installSpan.attributes["config_settings"], AttributeValue.string("[key:value]"))
        XCTAssertEqual(installSpan.events.map(\.name), ["agent_instance_initialized"])
        XCTAssertEqual(installSpan.events.first?.timestamp, installEvent)
    }

    func testColdStartSendsNoSpanWithTheOldName() {
        let names = sendColdStartWithInstallData().map(\.name)

        XCTAssertEqual(names.sorted(), ["AppStart", "SplunkRum.install"])
        XCTAssertFalse(names.contains("SplunkRum.initialize"))
    }


    // MARK: - Helpers

    /// Sends one cold start whose install data lies inside it, and returns the exported spans.
    private func sendColdStartWithInstallData() -> [SpanData] {
        let appStart = AppStart()
        appStart.processStartTimestamp = processStart
        appStart.destination = OTelDestination()

        appStart.reportAgentInitialize(
            start: installStart,
            end: installEnd,
            events: ["agent_instance_initialized": installEvent],
            configurationSettings: ["key": "value"]
        )
        appStart.process(
            event: .didFinishLaunching(
                processStart.addingTimeInterval(0.1),
                .foreground
            )
        )
        appStart.process(event: .didBecomeActive(processStart.addingTimeInterval(1)))

        // SimpleSpanProcessor exports on its own serial queue; forceFlush returns after that queue is empty.
        tracerProvider.forceFlush()

        return exporter.spans
    }
}


// MARK: - Span exporter

/// Collects exported spans in memory.
private final class InstallSpanRecordingExporter: SpanExporter {
    private let lock = NSLock()
    private var collected: [SpanData] = []

    var spans: [SpanData] {
        lock.withLock { collected }
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
