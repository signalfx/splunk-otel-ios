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
import XCTest

@testable import SplunkNetwork


// MARK: - Configuration Tests

final class NetworkTimingConfigurationTests: XCTestCase {

    func testDefaultConfigHasTimingEnabled() {
        let config = NetworkInstrumentationConfiguration()

        XCTAssertTrue(config.collectNetworkTiming)
    }

    func testConfigWithTimingDisabled() {
        let config = NetworkInstrumentationConfiguration(collectNetworkTiming: false)

        XCTAssertFalse(config.collectNetworkTiming)
        XCTAssertTrue(config.isEnabled)
        XCTAssertTrue(config.injectTraceHeaders)
    }

    func testFullConfigPreservesAllParameters() throws {
        let ignoreURLs = try IgnoreURLs(patterns: Set([".*\\.png$"]))

        let config = NetworkInstrumentationConfiguration(
            isEnabled: false,
            ignoreURLs: ignoreURLs,
            injectTraceHeaders: false,
            collectNetworkTiming: false
        )

        XCTAssertFalse(config.isEnabled)
        XCTAssertNotNil(config.ignoreURLs)
        XCTAssertFalse(config.injectTraceHeaders)
        XCTAssertFalse(config.collectNetworkTiming)
    }

    func testModuleStoresTimingFlag() {
        let module = NetworkInstrumentation()

        let config = NetworkInstrumentationConfiguration(collectNetworkTiming: true)
        module.install(with: config, remoteConfiguration: nil)

        XCTAssertTrue(module.isNetworkTimingEnabled)

        addTeardownBlock {
            module.uninstall()
        }
    }

    func testModuleDefaultsTimingToEnabled() {
        let module = NetworkInstrumentation()

        module.install(with: nil, remoteConfiguration: nil)

        XCTAssertTrue(module.isNetworkTimingEnabled)

        addTeardownBlock {
            module.uninstall()
        }
    }
}


// MARK: - NetworkTimingCollector Tests

@available(iOS 15, tvOS 15, macCatalyst 15, visionOS 1, *)
final class NetworkTimingCollectorTests: XCTestCase {

    // MARK: - Attribute Building Tests

    func testBuildTimingAttributes_AllDatesPresent() {
        let spanContext = SpanContext.create(
            traceId: TraceId.random(),
            spanId: SpanId.random(),
            traceFlags: TraceFlags(),
            traceState: TraceState()
        )
        let collector = NetworkTimingCollector(spanContext: spanContext)

        let baseDate = Date(timeIntervalSince1970: 1_700_000_000)
        let dates = TimingDates(
            fetchStart: baseDate,
            domainLookupStart: baseDate.addingTimeInterval(0.010),
            domainLookupEnd: baseDate.addingTimeInterval(0.050),
            connectStart: baseDate.addingTimeInterval(0.050),
            connectEnd: baseDate.addingTimeInterval(0.120),
            secureConnectionStart: baseDate.addingTimeInterval(0.060),
            secureConnectionEnd: baseDate.addingTimeInterval(0.110),
            requestStart: baseDate.addingTimeInterval(0.120),
            requestEnd: baseDate.addingTimeInterval(0.130),
            responseStart: baseDate.addingTimeInterval(0.200),
            responseEnd: baseDate.addingTimeInterval(0.500)
        )

        let attrs = collector.testBuildTimingAttributes(dates: dates)

        XCTAssertEqual(attrs["http.call.start_time"], .int(1_700_000_000_000))
        XCTAssertEqual(attrs["http.call.end_time"], .int(1_700_000_000_500))

        XCTAssertEqual(attrs["http.dns.start_time"], .int(1_700_000_000_010))
        XCTAssertEqual(attrs["http.dns.end_time"], .int(1_700_000_000_050))

        XCTAssertEqual(attrs["http.connect.start_time"], .int(1_700_000_000_050))
        XCTAssertEqual(attrs["http.connect.end_time"], .int(1_700_000_000_120))

        XCTAssertEqual(attrs["http.secure_connect.start_time"], .int(1_700_000_000_060))
        XCTAssertEqual(attrs["http.secure_connect.end_time"], .int(1_700_000_000_110))

        XCTAssertEqual(attrs["http.request.headers.start_time"], .int(1_700_000_000_120))
        XCTAssertEqual(attrs["http.request.body.end_time"], .int(1_700_000_000_130))

        XCTAssertEqual(attrs["http.response.headers.start_time"], .int(1_700_000_000_200))
        XCTAssertEqual(attrs["http.response.body.end_time"], .int(1_700_000_000_500))
    }

    func testBuildTimingAttributes_NilDatesOmitted() {
        let spanContext = SpanContext.create(
            traceId: TraceId.random(),
            spanId: SpanId.random(),
            traceFlags: TraceFlags(),
            traceState: TraceState()
        )
        let collector = NetworkTimingCollector(spanContext: spanContext)

        let baseDate = Date(timeIntervalSince1970: 1_700_000_000)
        let dates = TimingDates(
            fetchStart: baseDate,
            domainLookupStart: nil,
            domainLookupEnd: nil,
            connectStart: nil,
            connectEnd: nil,
            secureConnectionStart: nil,
            secureConnectionEnd: nil,
            requestStart: baseDate.addingTimeInterval(0.010),
            requestEnd: baseDate.addingTimeInterval(0.020),
            responseStart: baseDate.addingTimeInterval(0.100),
            responseEnd: baseDate.addingTimeInterval(0.200)
        )

        let attrs = collector.testBuildTimingAttributes(dates: dates)

        XCTAssertEqual(attrs["http.call.start_time"], .int(1_700_000_000_000))
        XCTAssertNotNil(attrs["http.request.headers.start_time"])
        XCTAssertNotNil(attrs["http.response.body.end_time"])

        XCTAssertNil(attrs["http.dns.start_time"])
        XCTAssertNil(attrs["http.dns.end_time"])
        XCTAssertNil(attrs["http.connect.start_time"])
        XCTAssertNil(attrs["http.connect.end_time"])
        XCTAssertNil(attrs["http.secure_connect.start_time"])
        XCTAssertNil(attrs["http.secure_connect.end_time"])
    }

    func testBuildTimingAttributes_ConnectionError_PartialData() {
        let spanContext = SpanContext.create(
            traceId: TraceId.random(),
            spanId: SpanId.random(),
            traceFlags: TraceFlags(),
            traceState: TraceState()
        )
        let collector = NetworkTimingCollector(spanContext: spanContext)

        let baseDate = Date(timeIntervalSince1970: 1_700_000_000)
        let dates = TimingDates(
            fetchStart: baseDate,
            domainLookupStart: baseDate.addingTimeInterval(0.010),
            domainLookupEnd: baseDate.addingTimeInterval(0.050),
            connectStart: baseDate.addingTimeInterval(0.050),
            connectEnd: nil,
            secureConnectionStart: nil,
            secureConnectionEnd: nil,
            requestStart: nil,
            requestEnd: nil,
            responseStart: nil,
            responseEnd: nil
        )

        let attrs = collector.testBuildTimingAttributes(dates: dates)

        XCTAssertEqual(attrs["http.call.start_time"], .int(1_700_000_000_000))
        XCTAssertNil(attrs["http.call.end_time"])
        XCTAssertEqual(attrs["http.dns.start_time"], .int(1_700_000_000_010))
        XCTAssertEqual(attrs["http.dns.end_time"], .int(1_700_000_000_050))
        XCTAssertEqual(attrs["http.connect.start_time"], .int(1_700_000_000_050))
        XCTAssertNil(attrs["http.connect.end_time"])
        XCTAssertNil(attrs["http.request.headers.start_time"])
        XCTAssertNil(attrs["http.response.headers.start_time"])
    }

    func testBuildTimingAttributes_AllNilDates() {
        let spanContext = SpanContext.create(
            traceId: TraceId.random(),
            spanId: SpanId.random(),
            traceFlags: TraceFlags(),
            traceState: TraceState()
        )
        let collector = NetworkTimingCollector(spanContext: spanContext)

        let dates = TimingDates(
            fetchStart: nil,
            domainLookupStart: nil,
            domainLookupEnd: nil,
            connectStart: nil,
            connectEnd: nil,
            secureConnectionStart: nil,
            secureConnectionEnd: nil,
            requestStart: nil,
            requestEnd: nil,
            responseStart: nil,
            responseEnd: nil
        )

        let attrs = collector.testBuildTimingAttributes(dates: dates)

        XCTAssertTrue(attrs.isEmpty)
    }
}


// MARK: - Test Support

/// Holds timing dates for test-driven attribute building without requiring
/// a real `URLSessionTaskTransactionMetrics` instance.
struct TimingDates {
    let fetchStart: Date?
    let domainLookupStart: Date?
    let domainLookupEnd: Date?
    let connectStart: Date?
    let connectEnd: Date?
    let secureConnectionStart: Date?
    let secureConnectionEnd: Date?
    let requestStart: Date?
    let requestEnd: Date?
    let responseStart: Date?
    let responseEnd: Date?
}


@available(iOS 15, tvOS 15, macCatalyst 15, visionOS 1, *)
extension NetworkTimingCollector {

    /// Test-only entry point into the attribute building logic.
    func testBuildTimingAttributes(dates: TimingDates) -> [String: AttributeValue] {
        buildTimingAttributes(
            fetchStart: dates.fetchStart,
            domainLookupStart: dates.domainLookupStart,
            domainLookupEnd: dates.domainLookupEnd,
            connectStart: dates.connectStart,
            connectEnd: dates.connectEnd,
            secureConnectionStart: dates.secureConnectionStart,
            secureConnectionEnd: dates.secureConnectionEnd,
            requestStart: dates.requestStart,
            requestEnd: dates.requestEnd,
            responseStart: dates.responseStart,
            responseEnd: dates.responseEnd
        )
    }
}
