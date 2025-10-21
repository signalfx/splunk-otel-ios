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
import os.log
import SplunkOpenTelemetryBackgroundExporter

///
/// This processor is used to send Session Replay events to the `OTLPReceiver`.
///
/// The reason why we need this custom processor is that `BatchLogRecordProcessor` doesn't support binary body.
/// This allows us to use custom types (especially the `AttributeValue` with `Data` field) to send binary body.
///
/// In case the binary body is supported in the future in the upstream, we can revert back to the processors-exporters chain.
public class OTLPSessionReplayEventProcessor: LogEventProcessor {

    // MARK: - Private properties

    private let logger = OSLog(subsystem: "com.splunk.rum", category: "OTLPSessionReplay")

    // MARK: - LogEventProcessor

    public var isEnabled: Bool {
        true
    }

    public init() {}

    public func onEmit(logRecord: SplunkReadableLogRecord) {
        log([logRecord])
    }

    // MARK: - Private methods

    /// ‼️ This code mirrors `SplunkStdoutLogExporter`.
    private func log(_ logRecords: [SplunkReadableLogRecord]) {
        for logRecord in logRecords {
            let bodyDescription: String

            switch logRecord.body {
            case let .data(data):
                bodyDescription = "\(data.count) bytes"

            default:
                bodyDescription = String(describing: logRecord.body)
            }

            // Log LogRecord data
            logger.log {
                var message = ""

                message += "------ 🪵 Log: ------\n"
                message += "Severity: \(String(describing: logRecord.severity))\n"
                message += "Body: \(bodyDescription)\n"
                message += "InstrumentationScopeInfo: \(logRecord.instrumentationScopeInfo)\n"
                message += "Timestamp: \(logRecord.timestamp.timeIntervalSince1970.toNanoseconds) (\(logRecord.timestamp.splunkFormatted()))\n"

                if let observedTimestamp = logRecord.observedTimestamp {
                    let observedTimestampNanoseconds = observedTimestamp.timeIntervalSince1970.toNanoseconds
                    message += "ObservedTimestamp: \(observedTimestampNanoseconds) (\(observedTimestamp.splunkFormatted()))\n"
                }
                else {
                    message += "ObservedTimestamp: -\n"
                }

                message += "SpanContext: \(String(describing: logRecord.spanContext))\n"

                // Log attributes
                message += "Attributes:\n"
                message += "  \(logRecord.attributes)\n"

                // Log resources
                message += "Resource:\n"
                message += "  \(logRecord.resource.attributes)\n"

                message += "--------------------\n"

                return message
            }
        }
    }
}
