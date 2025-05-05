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

public class OTLPGlobalAttributesLogRecordProcessor: LogRecordProcessor {
    private let proxy: LogRecordProcessor
    private let globalAttributes: [String: Any]

    public init(proxy: LogRecordProcessor, with globalAttributes: [String: Any]) {
        self.proxy = proxy
        self.globalAttributes = globalAttributes
    }

    // MARK: - LogRecordProcessor

    public func onEmit(logRecord: ReadableLogRecord) {
        // Convert global attributes to AttributeValue dictionary
        var convertedAttributes: [String: AttributeValue] = [:]
        for (key, value) in globalAttributes {
            if let stringValue = value as? String {
                convertedAttributes[key] = .string(stringValue)
            } else if let boolValue = value as? Bool {
                convertedAttributes[key] = .bool(boolValue)
            } else if let intValue = value as? Int {
                convertedAttributes[key] = .int(intValue)
            } else if let doubleValue = value as? Double {
                convertedAttributes[key] = .double(doubleValue)
            } else if let arrayValue = value as? [Any] {
                var attributeValues: [AttributeValue] = []
                for element in arrayValue {
                    if let stringElement = element as? String {
                        attributeValues.append(.string(stringElement))
                    } else if let boolElement = element as? Bool {
                        attributeValues.append(.bool(boolElement))
                    } else if let intElement = element as? Int {
                        attributeValues.append(.int(intElement))
                    } else if let doubleElement = element as? Double {
                        attributeValues.append(.double(doubleElement))
                    }
                }
                convertedAttributes[key] = .array(AttributeArray(values: attributeValues))
            }
        }

        var mergedAttributes = convertedAttributes
        mergedAttributes.merge(logRecord.attributes) { _, new in new }

        // Create a new log record with the merged attributes
        let updatedLogRecord = ReadableLogRecord(
            resource: logRecord.resource,
            instrumentationScopeInfo: logRecord.instrumentationScopeInfo,
            timestamp: logRecord.timestamp,
            observedTimestamp: logRecord.observedTimestamp,
            spanContext: logRecord.spanContext,
            severity: logRecord.severity,
            body: logRecord.body,
            attributes: mergedAttributes
        )

        // Pass the updated log record to the proxy processor
        proxy.onEmit(logRecord: updatedLogRecord)
    }

    public func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult {
        return proxy.forceFlush(explicitTimeout: explicitTimeout)
    }

    public func shutdown(explicitTimeout: TimeInterval?) -> ExportResult {
        return proxy.shutdown(explicitTimeout: explicitTimeout)
    }
}
