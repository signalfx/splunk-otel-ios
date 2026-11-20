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
import SplunkCommon

@testable import SplunkOpenTelemetry

final class TracerProviderTestBuilder {

    static func build(
        runtimeAttributes: RuntimeAttributes,
        activityTracker: ActivityTracker,
        exporter: SpanExporter
    ) -> any TracerProvider {
        TracerProviderBuilder()
            .add(
                spanProcessor: OTLPAttributesSpanProcessor(
                    with: runtimeAttributes,
                    activityTracker: activityTracker
                )
            )
            .add(spanProcessor: SimpleSpanProcessor(spanExporter: exporter))
            .build()
    }

    /// Builds a tracer provider whose only span processor is the given in-memory batching processor.
    static func buildBatch(processor: OTLPBatchSpanProcessor) -> any TracerProvider {
        TracerProviderBuilder()
            .add(spanProcessor: processor)
            .build()
    }

    /// Builds a tracer provider that drops all spans (never samples), wired to the given batch processor.
    static func buildBatchNeverSampled(processor: OTLPBatchSpanProcessor) -> any TracerProvider {
        TracerProviderBuilder()
            .with(sampler: Samplers.alwaysOff)
            .add(spanProcessor: processor)
            .build()
    }
}
