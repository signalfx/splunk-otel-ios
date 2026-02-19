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
import XCTest

@testable import SplunkNetwork

final class TraceContextInjectorTests: XCTestCase {

    // MARK: - Test Helpers

    private func createValidSpanContext() -> SpanContext {
        SpanContext.create(
            traceId: TraceId.random(),
            spanId: SpanId.random(),
            traceFlags: TraceFlags().settingIsSampled(true),
            traceState: TraceState()
        )
    }

    private func createInvalidSpanContext() -> SpanContext {
        SpanContext.create(
            traceId: TraceId.invalid,
            spanId: SpanId.invalid,
            traceFlags: TraceFlags(),
            traceState: TraceState()
        )
    }

    // MARK: - injectTraceContext Tests

    func testInjectTraceContext_WithValidSpanContext() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/api/data"))
        var request = URLRequest(url: url)
        let spanContext = createValidSpanContext()

        let injectedRequest = TraceContextInjector.injectTraceContext(into: request, spanContext: spanContext)

        let traceparent = injectedRequest.value(forHTTPHeaderField: "traceparent")
        XCTAssertNotNil(traceparent, "traceparent header should be present")

        // Verify traceparent format: {version}-{trace-id}-{span-id}-{trace-flags}
        // Example: 00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01
        let parts = traceparent?.split(separator: "-")
        XCTAssertEqual(parts?.count, 4, "traceparent should have 4 parts")
        XCTAssertEqual(parts?[0], "00", "Version should be 00")
        XCTAssertEqual(parts?[1].count, 32, "Trace ID should be 32 hex chars")
        XCTAssertEqual(parts?[2].count, 16, "Span ID should be 16 hex chars")
        XCTAssertTrue(["00", "01"].contains(String(parts?[3] ?? "")), "Trace flags should be 00 or 01")
    }

    func testInjectTraceContext_WithInvalidSpanContext() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/api/data"))
        var request = URLRequest(url: url)
        let spanContext = createInvalidSpanContext()

        let injectedRequest = TraceContextInjector.injectTraceContext(into: request, spanContext: spanContext)

        let traceparent = injectedRequest.value(forHTTPHeaderField: "traceparent")
        XCTAssertNil(traceparent, "traceparent header should not be present for invalid span context")
    }

    func testInjectTraceContext_PreservesExistingHeaders() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/api/data"))
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer token123", forHTTPHeaderField: "Authorization")
        let spanContext = createValidSpanContext()

        let injectedRequest = TraceContextInjector.injectTraceContext(into: request, spanContext: spanContext)

        XCTAssertEqual(injectedRequest.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(injectedRequest.value(forHTTPHeaderField: "Authorization"), "Bearer token123")
        XCTAssertNotNil(injectedRequest.value(forHTTPHeaderField: "traceparent"))
    }

    func testInjectTraceContext_WithSampledFlag() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/api/data"))
        var request = URLRequest(url: url)
        let spanContext = SpanContext.create(
            traceId: TraceId.random(),
            spanId: SpanId.random(),
            traceFlags: TraceFlags().settingIsSampled(true),
            traceState: TraceState()
        )

        let injectedRequest = TraceContextInjector.injectTraceContext(into: request, spanContext: spanContext)

        let traceparent = injectedRequest.value(forHTTPHeaderField: "traceparent")
        XCTAssertTrue(traceparent?.hasSuffix("-01") ?? false, "Sampled flag should be 01")
    }

    func testInjectTraceContext_WithUnsampledFlag() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/api/data"))
        var request = URLRequest(url: url)
        let spanContext = SpanContext.create(
            traceId: TraceId.random(),
            spanId: SpanId.random(),
            traceFlags: TraceFlags().settingIsSampled(false),
            traceState: TraceState()
        )

        let injectedRequest = TraceContextInjector.injectTraceContext(into: request, spanContext: spanContext)

        let traceparent = injectedRequest.value(forHTTPHeaderField: "traceparent")
        XCTAssertTrue(traceparent?.hasSuffix("-00") ?? false, "Unsampled flag should be 00")
    }

    // MARK: - hasTraceContext Tests

    func testHasTraceContext_WhenPresent() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/api/data"))
        var request = URLRequest(url: url)
        request.setValue("00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01", forHTTPHeaderField: "traceparent")

        XCTAssertTrue(TraceContextInjector.hasTraceContext(in: request))
    }

    func testHasTraceContext_WhenAbsent() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/api/data"))
        let request = URLRequest(url: url)

        XCTAssertFalse(TraceContextInjector.hasTraceContext(in: request))
    }

    func testHasTraceContext_AfterInjection() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/api/data"))
        var request = URLRequest(url: url)
        let spanContext = createValidSpanContext()

        XCTAssertFalse(TraceContextInjector.hasTraceContext(in: request))

        request = TraceContextInjector.injectTraceContext(into: request, spanContext: spanContext)

        XCTAssertTrue(TraceContextInjector.hasTraceContext(in: request))
    }

    // MARK: - injectActiveTraceContext Tests

    func testInjectActiveTraceContext_WithNoActiveSpan() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/api/data"))
        let request = URLRequest(url: url)

        let injectedRequest = TraceContextInjector.injectActiveTraceContext(into: request)

        let traceparent = injectedRequest.value(forHTTPHeaderField: "traceparent")
        XCTAssertNil(traceparent, "No traceparent should be added when there's no active span")
    }

    // MARK: - NetworkInstrumentationConfiguration Tests

    func testNetworkInstrumentationConfiguration_DefaultInjectTraceHeaders() {
        let config = NetworkInstrumentationConfiguration()

        XCTAssertTrue(config.injectTraceHeaders, "injectTraceHeaders should default to true")
    }

    func testNetworkInstrumentationConfiguration_DisableInjectTraceHeaders() {
        let config = NetworkInstrumentationConfiguration(
            isEnabled: true,
            ignoreURLs: nil,
            injectTraceHeaders: false
        )

        XCTAssertFalse(config.injectTraceHeaders)
    }

    func testNetworkInstrumentationConfiguration_AllParameters() throws {
        let patterns = Set([".*\\.json$"])
        let ignoreURLs = try IgnoreURLs(patterns: patterns)

        let config = NetworkInstrumentationConfiguration(
            isEnabled: true,
            ignoreURLs: ignoreURLs,
            injectTraceHeaders: true
        )

        XCTAssertTrue(config.isEnabled)
        XCTAssertNotNil(config.ignoreURLs)
        XCTAssertTrue(config.injectTraceHeaders)
    }
}
