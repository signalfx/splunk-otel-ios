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
import Testing

@testable import SplunkOpenTelemetry

@Suite
struct OLTPAttributesSpanProcessorTests {

    @Test
    func screenSpanDoesNotReceiveRuntimeScreenName() {
        let exporter = MockSpanExporter()
        let activityTracker = MockActivityTracker()
        let runtimeAttributes = MockRuntimeAttributes(
            all: [
                "screen.name": "RuntimeScreen",
                "custom.attribute": "custom-value"
            ]
        )

        let tracerProvider = makeTracerProvider(
            runtimeAttributes: runtimeAttributes,
            activityTracker: activityTracker,
            exporter: exporter
        )
        let tracer = tracerProvider.get(
            instrumentationName: "test",
            instrumentationVersion: "1.0"
        )

        let span = tracer.spanBuilder(spanName: "app.ui.navigation").startSpan()
        span.end()

        #expect(activityTracker.trackedDates.count == 1)
        #expect(exporter.exportedSpans.count == 1)
        #expect(exporter.exportedSpans[0].attributes["screen.name"] == nil)
        #expect(exporter.exportedSpans[0].attributes["custom.attribute"]?.description == "custom-value")
    }

    @Test
    func nonScreenSpanReceivesRuntimeScreenName() {
        let exporter = MockSpanExporter()
        let activityTracker = MockActivityTracker()
        let runtimeAttributes = MockRuntimeAttributes(
            all: [
                "screen.name": "RuntimeScreen"
            ]
        )

        let tracerProvider = makeTracerProvider(
            runtimeAttributes: runtimeAttributes,
            activityTracker: activityTracker,
            exporter: exporter
        )
        let tracer = tracerProvider.get(
            instrumentationName: "test",
            instrumentationVersion: "1.0"
        )

        let span = tracer.spanBuilder(spanName: "background-task").startSpan()
        span.end()

        #expect(activityTracker.trackedDates.count == 1)
        #expect(exporter.exportedSpans.count == 1)
        #expect(exporter.exportedSpans[0].attributes["screen.name"]?.description == "RuntimeScreen")
    }

    private func makeTracerProvider(
        runtimeAttributes: RuntimeAttributes,
        activityTracker: ActivityTracker,
        exporter: SpanExporter
    ) -> any TracerProvider {
        TracerProviderBuilder()
            .add(
                spanProcessor: OLTPAttributesSpanProcessor(
                    with: runtimeAttributes,
                    activityTracker: activityTracker
                )
            )
            .add(spanProcessor: SimpleSpanProcessor(spanExporter: exporter))
            .build()
    }
}
