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

@testable import SplunkOpenTelemetry

final class OTLPGlobalAttributesSpanProcessorTests: XCTestCase {

    // MARK: - Tests

    func testSpanReceivesGlobalAttributes() throws {
        let exportedSpan = try recordedSpan(
            globalAttributes: [
                "app.version": .string("1.0")
            ]
        )

        XCTAssertEqual(exportedSpan.attributes["app.version"]?.description, "1.0")
    }

    func testSpanSkipsInternalGlobalAttributes() throws {
        let exportedSpan = try recordedSpan(
            globalAttributes: [
                "app.version": .string("1.0"),
                OTLPInternalGlobalAttributes.sessionReplayHideWireframe: .bool(true)
            ]
        )

        XCTAssertEqual(exportedSpan.attributes["app.version"]?.description, "1.0")
        XCTAssertNil(exportedSpan.attributes[OTLPInternalGlobalAttributes.sessionReplayHideWireframe])
    }


    // MARK: - Private

    private func recordedSpan(globalAttributes: [String: AttributeValue]) throws -> SpanData {
        let tracerProvider = TracerProviderBuilder()
            .add(
                spanProcessor: OTLPGlobalAttributesSpanProcessor {
                    globalAttributes
                }
            )
            .build()

        let tracer = tracerProvider.get(
            instrumentationName: "test",
            instrumentationVersion: "1.0"
        )

        let span = tracer.spanBuilder(spanName: "background-task").startSpan()
        span.end()
        let readableSpan = try XCTUnwrap(span as? ReadableSpan)

        return readableSpan.toSpanData()
    }
}
