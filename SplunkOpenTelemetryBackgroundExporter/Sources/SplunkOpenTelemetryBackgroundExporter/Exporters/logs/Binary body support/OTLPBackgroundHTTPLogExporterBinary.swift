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
import OpenTelemetrySdk

/// This class mirrors the `OTLPBackgroundHTTPLogExporter`, allows exporting `SplunkReadableLogRecord`.
///
/// These changes are implemented to add support for `SplunkReadableLogRecord` export:
/// - removes the `LogRecordExporter` protocol conformance,
/// - utilizes the `SplunkLogRecordAdapterJSON` for OTLP JSON encoding with binary body support
///
/// Binary data in the log body is encoded as base64 per OTLP JSON specification.
public class OTLPBackgroundHTTPLogExporterBinary: OTLPBackgroundHTTPBaseExporter {

    // MARK: - SplunkReadableLogRecord export

    /// Exports `SplunkReadableLogRecord` with binary body support.
    ///
    /// Binary data in the log body is encoded as base64 per OTLP JSON specification.
    public func export(logRecords: [SplunkReadableLogRecord], explicitTimeout: TimeInterval? = nil) -> OpenTelemetrySdk.ExportResult {
        guard !isDropModeEnabled else {
            return .success
        }

        // Convert log records to OTLP JSON models using our custom adapter
        // Binary body data will be base64 encoded
        let resourceLogs = SplunkLogRecordAdapterJSON.toResourceLogs(logRecords)

        // Skip if no log records to export (filter empty envelopes per OTLP spec)
        guard !resourceLogs.isEmpty else {
            return .success
        }

        let request = OTLPExportLogsServiceRequest(resourceLogs: resourceLogs)
        let requestId = UUID()

        do {
            // Encode to JSON instead of protobuf binary
            let storeData = try JSONEncoder().encode(request)

            // If no endpoint is configured, store in pending folder for later
            if isPendingEndpoint {
                try diskStorage.insert(
                    storeData,
                    forKey: KeyBuilder(
                        requestId.uuidString,
                        parrentKeyBuilder: getPendingStorageKey()
                    )
                )
                return .success
            }

            // Store in active folder
            try diskStorage.insert(
                storeData,
                forKey: KeyBuilder(
                    requestId.uuidString,
                    parrentKeyBuilder: getStorageKey()
                )
            )
        }
        catch {

            return .failure
        }

        // Only send if we have an endpoint
        guard let endpoint else {
            return .success
        }

        let timeout = min(explicitTimeout ?? TimeInterval.greatestFiniteMagnitude, config.timeout)

        let requestDescriptor = RequestDescriptor(
            id: requestId,
            endpoint: endpoint,
            explicitTimeout: timeout,
            fileKeyType: getFileKeyType(),
            headers: headers,
            payloadFormat: .json
        )

        do {
            try httpClient.send(requestDescriptor)

            return .success
        }
        catch {

            return .failure
        }
    }


    // MARK: - Local override

    override func getFileKeyType() -> String {
        fileType ?? "logs_binary"
    }
}
