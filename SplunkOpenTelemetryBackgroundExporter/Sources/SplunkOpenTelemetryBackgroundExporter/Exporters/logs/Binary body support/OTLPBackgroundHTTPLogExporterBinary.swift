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

import CiscoDiskStorage
import Foundation
import OpenTelemetryProtocolExporterCommon
import OpenTelemetrySdk

/// This class mirrors the `OTLPBackgroundHTTPLogExporter`, allows exporting `SplunkReadableLogRecord`.
///
/// These changes are implemented to add support for `SplunkReadableLogRecord` export:
/// - removes the `LogRecordExporter` protocol conformance,
/// - utilizes the `SplunkLogRecordAdapter`
public class OTLPBackgroundHTTPLogExporterBinary: OTLPBackgroundHTTPBaseExporter {

    // MARK: - SplunkReadableLogRecord export

    /// Exports `SplunkReadableLogRecord`.
    public func export(logRecords: [SplunkReadableLogRecord], explicitTimeout: TimeInterval? = nil) -> OpenTelemetrySdk.ExportResult {
        let body = Opentelemetry_Proto_Collector_Logs_V1_ExportLogsServiceRequest.with { request in
            request.resourceLogs = SplunkLogRecordAdapter.toProtoResourceRecordLog(logRecordList: logRecords)
        }

        let requestId = UUID()

        do {
            let storeData = try body.serializedData()
            try diskStorage.insert(
                storeData,
                forKey: KeyBuilder(
                    requestId.uuidString,
                    parrentKeyBuilder: getStorageKey()
                )
            )
        } catch {

            return .failure
        }

        let timeout = min(explicitTimeout ?? TimeInterval.greatestFiniteMagnitude, config.timeout)

        let requestDescriptor = RequestDescriptor(
            id: requestId,
            endpoint: endpoint,
            explicitTimeout: timeout,
            fileKeyType: getFileKeyType()
        )

        do {
            try httpClient.send(requestDescriptor)

            return .success
        } catch {

            return .failure
        }
    }


    // MARK: - Local override

    override func getFileKeyType() -> String {
        fileType ?? "logs_binary"
    }
}
