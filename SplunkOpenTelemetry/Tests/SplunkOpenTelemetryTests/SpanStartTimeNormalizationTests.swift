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
import OpenTelemetrySdk
import Testing

@testable import SplunkOpenTelemetry

@Suite
struct SpanStartTimeNormalizationTests {

    @Test
    func normalizeNetworkSpanStartTimeUsesRequestStartedEvent() {
        let originalStartTime = Date(timeIntervalSince1970: 10)
        let requestStartedTime = Date(timeIntervalSince1970: 12)
        let endTime = Date(timeIntervalSince1970: 15)
        let span = makeSpanData(
            startTime: originalStartTime,
            endTime: endTime,
            events: [
                SpanData.Event(name: "http.request.started", timestamp: requestStartedTime),
                SpanData.Event(name: "other", timestamp: Date(timeIntervalSince1970: 13))
            ]
        )

        let normalizedSpan = normalizeNetworkSpanStartTime(span)

        #expect(normalizedSpan.startTime == requestStartedTime)
    }

    @Test
    func normalizeNetworkSpanStartTimeLeavesSpanUnchangedWhenEventIsOutOfBounds() {
        let originalStartTime = Date(timeIntervalSince1970: 10)
        let endTime = Date(timeIntervalSince1970: 15)
        let span = makeSpanData(
            startTime: originalStartTime,
            endTime: endTime,
            events: [
                SpanData.Event(name: "http.request.started", timestamp: Date(timeIntervalSince1970: 16))
            ]
        )

        let normalizedSpan = normalizeNetworkSpanStartTime(span)

        #expect(normalizedSpan.startTime == originalStartTime)
    }

    private func makeSpanData(
        startTime: Date,
        endTime: Date,
        events: [SpanData.Event]
    ) -> SpanData {
        let exporter = NoOpSpanExporter()
        let processor = SimpleSpanProcessor(spanExporter: exporter)
        let tracerProvider = TracerProviderBuilder()
            .add(spanProcessor: processor)
            .build()
        let tracer = tracerProvider.get(instrumentationName: "test", instrumentationVersion: "1.0")

        let span = tracer.spanBuilder(spanName: "HTTP GET").startSpan()
        span.end()

        guard let readableSpan = span as? ReadableSpan else {
            fatalError("Could not get SpanData from span")
        }

        var spanData = readableSpan.toSpanData()
        spanData = spanData.settingStartTime(startTime)
        spanData = spanData.settingEndTime(endTime)
        spanData = spanData.settingEvents(events)
        return spanData.settingTotalRecordedEvents(events.count)
    }
}

private final class NoOpSpanExporter: SpanExporter {
    func export(spans _: [SpanData], explicitTimeout _: TimeInterval?) -> SpanExporterResultCode {
        .success
    }

    func flush(explicitTimeout _: TimeInterval?) -> SpanExporterResultCode {
        .success
    }

    func shutdown(explicitTimeout _: TimeInterval?) {}
}
