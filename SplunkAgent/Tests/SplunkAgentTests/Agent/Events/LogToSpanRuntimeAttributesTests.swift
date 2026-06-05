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
import SplunkCommon
@_spi(SplunkTesting) import SplunkOpenTelemetry
import XCTest

final class LogToSpanRuntimeAttributesTests: XCTestCase {

    // MARK: - Log record attributes

    func testDirectLogRecordDoesNotReceiveRuntimeScreenNameWithoutLogRecordProcessor() {
        let exporter = CapturingLogRecordExporter()
        let loggerProvider = LoggerProviderBuilder()
            .with(
                processors: [
                    SimpleLogRecordProcessor(logRecordExporter: exporter)
                ]
            )
            .build()

        emitLifecycleLog(using: loggerProvider)

        XCTAssertEqual(exporter.exportedLogRecords.count, 1)
        XCTAssertNil(exporter.exportedLogRecords[0].attributes["screen.name"])
    }


    // MARK: - Log to span attributes

    func testLogToSpanConvertedLifecycleEventReceivesRuntimeScreenNameFromSpanProcessor() {
        let exportExpectation = expectation(description: "Log record converted to span")
        let spanExporter = CapturingSpanExporter(exportExpectation: exportExpectation)
        let activityTracker = CapturingActivityTracker()
        let runtimeAttributes = StaticRuntimeAttributes(
            all: [
                "screen.name": "CheckoutViewController"
            ]
        )
        let tracerProvider = TracerProviderBuilder()
            .add(
                spanProcessor: OTLPAttributesSpanProcessor(
                    with: runtimeAttributes,
                    activityTracker: activityTracker
                )
            )
            .add(spanProcessor: SimpleSpanProcessor(spanExporter: spanExporter))
            .build()
        OpenTelemetry.registerTracerProvider(tracerProvider: tracerProvider)

        let loggerProvider = LoggerProviderBuilder()
            .with(
                processors: [
                    SimpleLogRecordProcessor(
                        logRecordExporter: OTLPLogToSpanExporter(agentVersion: "test")
                    )
                ]
            )
            .build()

        emitLifecycleLog(using: loggerProvider)

        wait(for: [exportExpectation], timeout: 1)

        XCTAssertEqual(activityTracker.trackedDates.count, 1)
        XCTAssertEqual(spanExporter.exportedSpans.count, 1)
        XCTAssertEqual(spanExporter.exportedSpans[0].name, "app.ui.lifecycle")
        XCTAssertEqual(spanExporter.exportedSpans[0].attributes["screen.name"]?.description, "CheckoutViewController")
    }


    // MARK: - Helpers

    private func emitLifecycleLog(using loggerProvider: LoggerProvider) {
        let logger = loggerProvider.get(instrumentationScopeName: "test-lifecycle")
        logger
            .logRecordBuilder()
            .setAttributes(
                [
                    "event.name": .string("app.ui.lifecycle"),
                    "component": .string("ui"),
                    "lifecycle.action": .string("resumed")
                ]
            )
            .emit()
    }
}

private final class CapturingLogRecordExporter: LogRecordExporter {
    private(set) var exportedLogRecords: [ReadableLogRecord] = []

    func export(logRecords: [ReadableLogRecord], explicitTimeout _: TimeInterval?) -> ExportResult {
        exportedLogRecords.append(contentsOf: logRecords)
        return .success
    }

    func shutdown(explicitTimeout _: TimeInterval?) {}

    func forceFlush(explicitTimeout _: TimeInterval?) -> ExportResult {
        .success
    }
}

private final class CapturingSpanExporter: SpanExporter {
    private let exportExpectation: XCTestExpectation?
    private(set) var exportedSpans: [SpanData] = []

    init(exportExpectation: XCTestExpectation? = nil) {
        self.exportExpectation = exportExpectation
    }

    func export(spans: [SpanData], explicitTimeout _: TimeInterval?) -> SpanExporterResultCode {
        exportedSpans.append(contentsOf: spans)
        exportExpectation?.fulfill()
        return .success
    }

    func flush(explicitTimeout _: TimeInterval?) -> SpanExporterResultCode {
        .success
    }

    func shutdown(explicitTimeout _: TimeInterval?) {}
}

private final class CapturingActivityTracker: ActivityTracker {
    private(set) var trackedDates: [Date] = []

    func trackActivity(at date: Date) {
        trackedDates.append(date)
    }
}

private final class StaticRuntimeAttributes: RuntimeAttributes {
    let all: [String: Any]

    init(all: [String: Any]) {
        self.all = all
    }
}
