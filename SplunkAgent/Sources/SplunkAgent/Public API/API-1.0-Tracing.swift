//
/*
Copyright 2025 Splunk Inc.

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
internal import SplunkNetwork

/// Provides utilities for distributed tracing.
///
/// Use this class to manually inject W3C trace context headers into HTTP requests
/// when automatic injection is disabled or when using custom HTTP clients.
///
/// ## Automatic vs Manual Injection
///
/// By default, the Splunk Agent automatically injects W3C trace context headers (`traceparent`
/// and `tracestate`) into outgoing `URLSession` requests. This enables distributed trace
/// correlation between your iOS app and backend services.
///
/// Manual injection is useful when:
/// - You're using a custom HTTP client that doesn't use `URLSession`
/// - You've disabled automatic injection via `NetworkInstrumentationConfiguration.injectTraceHeaders`
/// - You need to inject headers at a specific point in your request lifecycle
///
/// ## Example Usage
///
/// ```swift
/// // Inject trace context from the active span
/// var request = URLRequest(url: url)
/// request = Tracing.injectTraceContext(into: request)
///
/// // Or inject from a specific span context
/// let span = tracer.spanBuilder(spanName: "my-span").startSpan()
/// request = Tracing.injectTraceContext(into: request, spanContext: span.context)
/// span.end()
/// ```
public final class Tracing {

    private init() {}

    // MARK: - W3C Trace Context Injection

    /// Injects W3C trace context headers into a URLRequest using the active span.
    ///
    /// If there is no active span in the current context, the request is returned unchanged.
    /// This method adds the `traceparent` header and optionally the `tracestate` header
    /// according to the W3C Trace Context specification.
    ///
    /// - Parameter request: The URLRequest to inject headers into.
    /// - Returns: A new URLRequest with trace context headers injected, or the original if no active span.
    ///
    /// ## Example
    ///
    /// ```swift
    /// var request = URLRequest(url: url)
    /// request = Tracing.injectTraceContext(into: request)
    /// let task = URLSession.shared.dataTask(with: request) { ... }
    /// task.resume()
    /// ```
    public static func injectTraceContext(into request: URLRequest) -> URLRequest {
        TraceContextInjector.injectActiveTraceContext(into: request)
    }

    /// Injects W3C trace context headers into a URLRequest using a specific span context.
    ///
    /// This method adds the `traceparent` header and optionally the `tracestate` header
    /// according to the W3C Trace Context specification.
    ///
    /// - Parameters:
    ///   - request: The URLRequest to inject headers into.
    ///   - spanContext: The span context to propagate.
    /// - Returns: A new URLRequest with trace context headers injected.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let span = OpenTelemetry.instance.tracerProvider
    ///     .get(instrumentationName: "my-tracer")
    ///     .spanBuilder(spanName: "my-request")
    ///     .startSpan()
    ///
    /// var request = URLRequest(url: url)
    /// request = Tracing.injectTraceContext(into: request, spanContext: span.context)
    ///
    /// // Make request...
    ///
    /// span.end()
    /// ```
    public static func injectTraceContext(
        into request: URLRequest,
        spanContext: SpanContext
    ) -> URLRequest {
        TraceContextInjector.injectTraceContext(into: request, spanContext: spanContext)
    }

    /// Checks if trace context headers are already present in a request.
    ///
    /// This can be used to prevent double injection of trace context headers.
    ///
    /// - Parameter request: The URLRequest to check.
    /// - Returns: `true` if the `traceparent` header is already present.
    public static func hasTraceContext(in request: URLRequest) -> Bool {
        TraceContextInjector.hasTraceContext(in: request)
    }
}
