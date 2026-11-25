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

@testable import SplunkOpenTelemetry

/// Builds the session stages of the agent's span pipeline, for tests of the agent-only session keys.
enum SessionPolicyPipelineTestBuilder {

    /// The export chain under the session policy: the policy, then the interceptor with the session key check.
    static func buildExportChain(proxy: SpanExporter, interceptor: SplunkSpanInterceptor?) -> SpanExporter {
        SessionPolicySpanExporter(
            proxy: SpanInterceptorExporter(with: interceptor, proxy: proxy, requiresUnchangedSessionId: true)
        )
    }

    /// Starts and ends one span through the global attributes and attributes processors.
    ///
    /// - Parameters:
    ///   - spanAttributes: Attributes set on the span builder, before the processors run.
    ///   - globalAttributes: The app's global attributes.
    ///   - runtimeSessionId: The `session.id` of the agent's runtime attributes, or `nil` for no session.
    ///   - ownsSessionId: Whether both processors treat the session keys as agent-only, as in the agent's pipeline.
    ///
    /// - Returns: The ended span as an exporter receives it.
    static func startAndEndSpan(
        spanAttributes: [String: AttributeValue] = [:],
        globalAttributes: [String: AttributeValue],
        runtimeSessionId: String?,
        ownsSessionId: Bool
    ) -> SpanData {
        // The processor holds the runtime attributes without owning them, so this reference keeps them alive.
        let runtimeAttributes = MockRuntimeAttributes(sessionId: runtimeSessionId)
        let provider = TracerProviderBuilder()
            .add(spanProcessor: OTLPGlobalAttributesSpanProcessor(with: { globalAttributes }, ownsSessionId: ownsSessionId))
            .add(
                spanProcessor: OTLPAttributesSpanProcessor(
                    with: runtimeAttributes,
                    activityTracker: MockActivityTracker(),
                    ownsSessionId: ownsSessionId
                )
            )
            .build()
        let builder = provider.get(instrumentationName: "session-policy-pipeline-test-builder")
            .spanBuilder(spanName: "test")
        for (key, value) in spanAttributes {
            builder.setAttribute(key: key, value: value)
        }
        let span = builder.startSpan()
        span.end()

        // The SDK tracer provider always creates readable spans.
        guard let readableSpan = span as? ReadableSpan else {
            preconditionFailure("Expected an SDK readable span")
        }

        return withExtendedLifetime(runtimeAttributes) {
            readableSpan.toSpanData()
        }
    }
}
