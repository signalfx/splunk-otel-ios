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
import XCTest

@testable import SplunkOpenTelemetry

final class NetworkSpanStartTimeNormalizationTests: XCTestCase {

    func testNetworkSpanStartTimeUsesRequestStartedEvent() throws {
        let creationTime = Date(timeIntervalSince1970: 100)
        let requestStarted = Date(timeIntervalSince1970: 101)
        let endTime = Date(timeIntervalSince1970: 102)
        let span = try makeSpanData(
            name: NetworkInstrumentationConstants.httpSpanNamePrefix + "GET",
            startTime: creationTime,
            endTime: endTime,
            events: [
                SpanData.Event(
                    name: NetworkInstrumentationConstants.requestStartedEventName,
                    timestamp: requestStarted
                )
            ]
        )

        let normalized = normalizeNetworkSpanStartTime(span)

        XCTAssertEqual(normalized.startTime, requestStarted)
        XCTAssertEqual(normalized.endTime, endTime)
    }

    func testNonNetworkSpanIsNotNormalized() throws {
        let creationTime = Date(timeIntervalSince1970: 100)
        let span = try makeSpanData(
            name: "app.ui.navigation",
            startTime: creationTime,
            endTime: Date(timeIntervalSince1970: 102),
            events: [
                SpanData.Event(
                    name: NetworkInstrumentationConstants.requestStartedEventName,
                    timestamp: Date(timeIntervalSince1970: 101)
                )
            ]
        )

        XCTAssertEqual(normalizeNetworkSpanStartTime(span).startTime, creationTime)
    }

    func testCustomHttpSpanIsNotNormalized() throws {
        let creationTime = Date(timeIntervalSince1970: 100)
        let span = try makeSpanData(
            name: NetworkInstrumentationConstants.httpSpanNamePrefix + "GET",
            startTime: creationTime,
            endTime: Date(timeIntervalSince1970: 102),
            events: [
                SpanData.Event(
                    name: NetworkInstrumentationConstants.requestStartedEventName,
                    timestamp: Date(timeIntervalSince1970: 101)
                )
            ],
            instrumentationName: "CustomInstrumentation"
        )

        XCTAssertEqual(normalizeNetworkSpanStartTime(span).startTime, creationTime)
    }

    func testInvalidRequestStartedTimestampIsIgnored() throws {
        let creationTime = Date(timeIntervalSince1970: 100)
        let span = try makeSpanData(
            name: NetworkInstrumentationConstants.httpSpanNamePrefix + "GET",
            startTime: creationTime,
            endTime: Date(timeIntervalSince1970: 102),
            events: [
                SpanData.Event(
                    name: NetworkInstrumentationConstants.requestStartedEventName,
                    timestamp: Date(timeIntervalSince1970: 103)
                )
            ]
        )

        XCTAssertEqual(normalizeNetworkSpanStartTime(span).startTime, creationTime)
    }

    private func makeSpanData(
        name: String,
        startTime: Date,
        endTime: Date,
        events: [SpanData.Event],
        instrumentationName: String = NetworkInstrumentationConstants.instrumentationName
    ) throws -> SpanData {
        let tracerProvider = TracerProviderBuilder()
            .add(spanProcessor: SimpleSpanProcessor(spanExporter: MockSpanExporter()))
            .build()
        let tracer = tracerProvider.get(instrumentationName: instrumentationName)
        let span = tracer.spanBuilder(spanName: name)
            .setStartTime(time: startTime)
            .startSpan()

        for event in events {
            span.addEvent(name: event.name, attributes: event.attributes, timestamp: event.timestamp)
        }
        span.end(time: endTime)

        let readableSpan = try XCTUnwrap(span as? ReadableSpan)
        return readableSpan.toSpanData()
    }
}
