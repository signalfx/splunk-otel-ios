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
import SplunkSharedProtocols

/// The class implements a generic log record processor that adds runtime attributes to all records.
public class OTLPAttributesLogRecordProcessor: LogRecordProcessor {

    // MARK: - Private

    private let proxy: LogRecordProcessor
    private unowned let runtimeAttributes: any RuntimeAttributes


    // MARK: - Initialization

    /// Initializes new log record processor with given runtime attributes.
    ///
    /// - Parameter runtimeAttributes: An object that holds and manages runtime attributes.
    ///
    /// - Note: The processor itself does not own the object with runtime attributes.
    ///         So, ensuring its existence outside this processor is always necessary.
    public init(proxy: LogRecordProcessor, with runtimeAttributes: RuntimeAttributes) {
        self.proxy = proxy
        self.runtimeAttributes = runtimeAttributes
    }


    // MARK: - LogRecordProcessor methods

    public func onEmit(logRecord: OpenTelemetrySdk.ReadableLogRecord) {
        var updatedAttributes = logRecord.attributes

        for (key, value) in runtimeAttributes.all {
            if let attributeValue = AttributeValue(value) {
                updatedAttributes[key] = attributeValue
            }
        }

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

        proxy.onEmit(logRecord: updatedLogRecord)
    }
    
    func forceFlush() -> ExportResult {
        proxy.forceFlush()
    }

    func shutdown() -> ExportResult {
        proxy.shutdown()
    }

    public func shutdown(explicitTimeout: TimeInterval?) -> OpenTelemetrySdk.ExportResult {
        proxy.shutdown(explicitTimeout: explicitTimeout)
    }

    public func forceFlush(explicitTimeout: TimeInterval?) -> OpenTelemetrySdk.ExportResult {
        proxy.forceFlush(explicitTimeout: explicitTimeout)
    }
}
