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
import XCTest

@testable import SplunkOpenTelemetry

/// `SpanInterceptorExporter` belongs to SplunkOpenTelemetry, but `SplunkOpenTelemetryTests`
/// is disabled in `SplunkAgent.xctestplan`, so these tests live here to run in CI.
final class SpanInterceptorExporterDidInterceptTests: XCTestCase {

    func testReportsTheSpansPassedOnToTheExporter() throws {
        let proxy = MockSpanExporter()
        var reportedNames: [String] = []
        let exporter = SpanInterceptorExporter(
            with: nil,
            proxy: proxy,
            didIntercept: { reportedNames = $0.map(\.name) }
        )

        _ = try exporter.export(spans: [makeSpan(name: "first"), makeSpan(name: "second")], explicitTimeout: nil)

        XCTAssertEqual(reportedNames, ["first", "second"])
        XCTAssertEqual(reportedNames, proxy.exportedSpans.map(\.name))
    }

    func testDoesNotReportSpansDroppedByInterceptor() throws {
        let proxy = MockSpanExporter()
        var reportedNames: [String] = []
        let exporter = SpanInterceptorExporter(
            with: { $0.name == "dropped" ? nil : $0 },
            proxy: proxy,
            didIntercept: { reportedNames = $0.map(\.name) }
        )

        _ = try exporter.export(spans: [makeSpan(name: "dropped"), makeSpan(name: "kept")], explicitTimeout: nil)

        XCTAssertEqual(reportedNames, ["kept"])
        XCTAssertEqual(reportedNames, proxy.exportedSpans.map(\.name))
    }

    func testReportsInterceptorModifications() throws {
        var reportedSessionIds: [String] = []
        let exporter = SpanInterceptorExporter(
            with: { span in
                var rewritten = span
                return rewritten.settingAttributes(["session.id": .string("rewritten")])
            },
            proxy: MockSpanExporter(),
            didIntercept: { spans in
                reportedSessionIds = spans.compactMap { span in
                    guard case let .string(id) = span.attributes["session.id"] else {
                        return nil
                    }

                    return id
                }
            }
        )

        _ = try exporter.export(spans: [makeSpan(name: "span")], explicitTimeout: nil)

        XCTAssertEqual(reportedSessionIds, ["rewritten"])
    }

    private func makeSpan(name: String) throws -> SpanData {
        let tracerProvider = TracerProviderBuilder()
            .add(spanProcessor: SimpleSpanProcessor(spanExporter: MockSpanExporter()))
            .build()
        let span = tracerProvider.get(instrumentationName: "test").spanBuilder(spanName: name).startSpan()
        span.end()

        let readableSpan = try XCTUnwrap(span as? ReadableSpan)
        return readableSpan.toSpanData()
    }
}
