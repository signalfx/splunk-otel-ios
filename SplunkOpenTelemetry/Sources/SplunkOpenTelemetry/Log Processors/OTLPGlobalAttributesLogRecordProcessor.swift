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
import OpenTelemetrySdk
import SplunkCommon

/// A log record processor that enriches each `ReadableLogRecord` with a set of global attributes.
///
/// This processor retrieves attributes from a provided closure at the time a log record is emitted
/// and adds them to the record before passing it to a downstream (proxied) processor.
public class OTLPGlobalAttributesLogRecordProcessor: LogRecordProcessor {
    private let proxy: LogRecordProcessor
    private let globalAttributes: () -> [String: AttributeValue]

    /// Initializes a new global attributes log record processor.
    ///
    /// - Parameters:
    ///   - proxy: The next `LogRecordProcessor` in the processing chain to which the enriched log record will be passed.
    ///   - globalAttributes: A closure that returns a dictionary of attributes to be added to each log record. This closure is called for every log record processed.
    public init(proxy: LogRecordProcessor, with globalAttributes: @escaping () -> [String: AttributeValue]) {
        self.proxy = proxy
        self.globalAttributes = globalAttributes
    }

    // MARK: - LogRecordProcessor

    /// Called when a `ReadableLogRecord` is emitted.
    ///
    /// This method adds the global attributes to the log record and then forwards it to the proxied processor.
    /// - Parameter logRecord: The log record to be processed.
    public func onEmit(logRecord: ReadableLogRecord) {

        var updatedAttributes = logRecord.attributes

        // Add global attributes into the log record's attributes
        for (key, value) in globalAttributes() {
            updatedAttributes[key] = value
        }

        // Create a new log record with the merged attributes
        let updatedLogRecord = ReadableLogRecord(
            resource: logRecord.resource,
            instrumentationScopeInfo: logRecord.instrumentationScopeInfo,
            timestamp: logRecord.timestamp,
            observedTimestamp: logRecord.observedTimestamp,
            spanContext: logRecord.spanContext,
            severity: logRecord.severity,
            body: logRecord.body,
            attributes: updatedAttributes
        )

        // Pass the updated log record to the proxy processor
        proxy.onEmit(logRecord: updatedLogRecord)
    }

    /// Forces the proxied processor to flush any pending log records.
    /// - Parameter explicitTimeout: The explicit timeout for the flush operation.
    /// - Returns: The result of the flush operation from the proxied processor.
    public func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult {
        return proxy.forceFlush(explicitTimeout: explicitTimeout)
    }

    /// Shuts down the processor and forwards the call to the proxied processor.
    /// - Parameter explicitTimeout: The explicit timeout for the shutdown operation.
    /// - Returns: The result of the shutdown operation from the proxied processor.
    public func shutdown(explicitTimeout: TimeInterval?) -> ExportResult {
        return proxy.shutdown(explicitTimeout: explicitTimeout)
    }
}
