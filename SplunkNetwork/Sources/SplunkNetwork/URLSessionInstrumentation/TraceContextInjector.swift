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

/// Handles injection of W3C Trace Context headers into outgoing HTTP requests.
///
/// This utility uses the OpenTelemetry `W3CTraceContextPropagator` to inject
/// `traceparent` and `tracestate` headers for distributed tracing.
public enum TraceContextInjector {

    // MARK: - Setter Implementation

    /// A setter implementation that writes key-value pairs to a dictionary.
    private struct DictionarySetter: Setter {
        func set(carrier: inout [String: String], key: String, value: String) {
            carrier[key] = value
        }
    }

    // MARK: - Public API

    /// Injects W3C trace context headers into a URLRequest.
    ///
    /// Uses the registered `TextMapPropagator` from OpenTelemetry to inject `traceparent`
    /// and optionally `tracestate` headers into the request, enabling distributed trace correlation.
    ///
    /// - Parameters:
    ///   - request: The URLRequest to inject headers into.
    ///   - spanContext: The span context to propagate.
    /// - Returns: A new URLRequest with trace context headers injected.
    public static func injectTraceContext(into request: URLRequest, spanContext: SpanContext) -> URLRequest {
        var mutableRequest = request

        // Use the registered propagator from OpenTelemetry instance
        let propagator = OpenTelemetry.instance.propagators.textMapPropagator
        var headers: [String: String] = [:]

        // Inject trace context headers
        propagator.inject(spanContext: spanContext, carrier: &headers, setter: DictionarySetter())

        // Merge trace headers into the request
        for (key, value) in headers {
            mutableRequest.setValue(value, forHTTPHeaderField: key)
        }

        return mutableRequest
    }

    /// Injects W3C trace context headers into a URLRequest using the active span.
    ///
    /// If there is no active span in the current context, the request is returned unchanged.
    ///
    /// - Parameter request: The URLRequest to inject headers into.
    /// - Returns: A new URLRequest with trace context headers injected, or the original if no active span.
    public static func injectActiveTraceContext(into request: URLRequest) -> URLRequest {
        guard let activeSpan = OpenTelemetry.instance.contextProvider.activeSpan else {
            return request
        }

        return injectTraceContext(into: request, spanContext: activeSpan.context)
    }

    /// Checks if trace context headers are already present in a request.
    ///
    /// This can be used to prevent double injection.
    ///
    /// - Parameter request: The URLRequest to check.
    /// - Returns: `true` if the `traceparent` header is already present.
    public static func hasTraceContext(in request: URLRequest) -> Bool {
        request.value(forHTTPHeaderField: "traceparent") != nil
    }
}
