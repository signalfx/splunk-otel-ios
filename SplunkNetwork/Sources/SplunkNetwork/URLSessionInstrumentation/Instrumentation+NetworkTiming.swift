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

// MARK: - Associated Object Key

private var associatedKeyTimingCollector: UInt8 = 0

// MARK: - NetworkTimingCollector

/// Collects `URLSessionTaskTransactionMetrics` for an instrumented HTTP task and emits
/// a network timing log record linked to the original HTTP span.
///
/// Instances are set as the per-task delegate (`task.delegate`, iOS 15+) so they receive
/// the `urlSession(_:task:didFinishCollecting:)` callback after the task completes.
@available(iOS 15, tvOS 15, macCatalyst 15, visionOS 1, *)
final class NetworkTimingCollector: NSObject, URLSessionTaskDelegate {

    private let spanContext: SpanContext

    init(spanContext: SpanContext) {
        self.spanContext = spanContext
        super.init()
    }

    // MARK: - URLSessionTaskDelegate

    func urlSession(_: URLSession, task _: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        guard let transaction = metrics.transactionMetrics.last
        else {
            return
        }

        let attributes = buildTimingAttributes(from: transaction)

        emitTimingLog(attributes: attributes, redirectCount: metrics.redirectCount)
    }

    // MARK: - Attribute Building

    /// Converts `URLSessionTaskTransactionMetrics` dates into epoch-millisecond attributes.
    private func buildTimingAttributes(
        from transaction: URLSessionTaskTransactionMetrics
    ) -> [String: AttributeValue] {
        buildTimingAttributes(
            fetchStart: transaction.fetchStartDate,
            domainLookupStart: transaction.domainLookupStartDate,
            domainLookupEnd: transaction.domainLookupEndDate,
            connectStart: transaction.connectStartDate,
            connectEnd: transaction.connectEndDate,
            secureConnectionStart: transaction.secureConnectionStartDate,
            secureConnectionEnd: transaction.secureConnectionEndDate,
            requestStart: transaction.requestStartDate,
            requestEnd: transaction.requestEndDate,
            responseStart: transaction.responseStartDate,
            responseEnd: transaction.responseEndDate
        )
    }

    // swiftlint:disable function_parameter_count
    /// Builds timing attributes from individual date values.
    ///
    /// Only non-nil dates produce attributes; phases that did not occur (e.g. DNS on a
    /// reused connection, TLS on plain HTTP) are omitted.
    func buildTimingAttributes(
        fetchStart: Date?,
        domainLookupStart: Date?,
        domainLookupEnd: Date?,
        connectStart: Date?,
        connectEnd: Date?,
        secureConnectionStart: Date?,
        secureConnectionEnd: Date?,
        requestStart: Date?,
        requestEnd: Date?,
        responseStart: Date?,
        responseEnd: Date?
    ) -> [String: AttributeValue] {
        // swiftlint:enable function_parameter_count
        var attrs: [String: AttributeValue] = [:]

        setIfPresent(&attrs, key: "http.call.start_time", date: fetchStart)
        setIfPresent(&attrs, key: "http.call.end_time", date: responseEnd)

        setIfPresent(&attrs, key: "http.dns.start_time", date: domainLookupStart)
        setIfPresent(&attrs, key: "http.dns.end_time", date: domainLookupEnd)

        setIfPresent(&attrs, key: "http.connect.start_time", date: connectStart)
        setIfPresent(&attrs, key: "http.connect.end_time", date: connectEnd)

        setIfPresent(&attrs, key: "http.secure_connect.start_time", date: secureConnectionStart)
        setIfPresent(&attrs, key: "http.secure_connect.end_time", date: secureConnectionEnd)

        // Apple does not separate request headers from body; requestStartDate covers both.
        setIfPresent(&attrs, key: "http.request.headers.start_time", date: requestStart)
        setIfPresent(&attrs, key: "http.request.headers.end_time", date: requestStart)
        setIfPresent(&attrs, key: "http.request.body.start_time", date: requestStart)
        setIfPresent(&attrs, key: "http.request.body.end_time", date: requestEnd)

        // responseStartDate marks the first byte after response headers are parsed.
        setIfPresent(&attrs, key: "http.response.headers.start_time", date: responseStart)
        setIfPresent(&attrs, key: "http.response.headers.end_time", date: responseStart)
        setIfPresent(&attrs, key: "http.response.body.start_time", date: responseStart)
        setIfPresent(&attrs, key: "http.response.body.end_time", date: responseEnd)

        return attrs
    }

    private func setIfPresent(_ attrs: inout [String: AttributeValue], key: String, date: Date?) {
        guard let date
        else {
            return
        }

        let epochMillis = Int(date.timeIntervalSince1970 * 1_000)
        attrs[key] = .int(epochMillis)
    }

    // MARK: - Log Emission

    private func emitTimingLog(attributes: [String: AttributeValue], redirectCount: Int) {
        var allAttributes = attributes

        allAttributes["event.name"] = .string("http.client.network_timing")

        if redirectCount > 0 {
            allAttributes["http.redirect_count"] = .int(redirectCount)
        }

        let logger = OpenTelemetry.instance
            .loggerProvider
            .get(instrumentationScopeName: "NetworkInstrumentation")

        logger
            .logRecordBuilder()
            .setSpanContext(spanContext)
            .setSeverity(.info)
            .setEventName("http.client.network_timing")
            .setTimestamp(Date())
            .setAttributes(allAttributes)
            .emit()
    }
}

// MARK: - Attach Helper

/// Attaches a `NetworkTimingCollector` to the task if network timing is enabled.
///
/// The collector is stored as an associated object on the task to ensure it is retained
/// for the duration of the task's lifetime, and set as the task's per-task delegate to
/// receive `didFinishCollecting` metrics.
func attachTimingCollectorIfEnabled(to task: URLSessionTask, spanContext: SpanContext) {
    guard #available(iOS 15, tvOS 15, macCatalyst 15, visionOS 1, *)
    else {
        return
    }

    guard NetworkInstrumentationManager.shared.getModule()?.isNetworkTimingEnabled == true
    else {
        return
    }

    let collector = NetworkTimingCollector(spanContext: spanContext)

    objc_setAssociatedObject(task, &associatedKeyTimingCollector, collector, .OBJC_ASSOCIATION_RETAIN)
    task.delegate = collector
}
