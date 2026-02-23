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

public class OTLPBackgroundHTTPLogExporter: OTLPBackgroundHTTPBaseExporter, LogRecordExporter {

    // MARK: - Implementation LogRecordExporter protocol

    public func export(logRecords: [OpenTelemetrySdk.ReadableLogRecord], explicitTimeout: TimeInterval? = nil) -> OpenTelemetrySdk.ExportResult {
        // Convert log records to OTLP JSON models using our custom adapter
        let resourceLogs = LogRecordAdapter.toResourceLogs(logRecords)

        // Skip if no log records to export (filter empty envelopes per OTLP spec)
        guard !resourceLogs.isEmpty else {
            return .success
        }

        let request = OTLPExportLogsServiceRequest(resourceLogs: resourceLogs)
        let requestId = UUID()

        do {
            // Encode to JSON instead of protobuf binary
            let storeData = try JSONEncoder().encode(request)
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

        let timeout = min(explicitTimeout ?? TimeInterval.greatestFiniteMagnitude, config.timeout)

        let requestDescriptor = RequestDescriptor(
            id: requestId,
            endpoint: endpoint,
            explicitTimeout: timeout,
            fileKeyType: getFileKeyType(),
            headers: headers,
            contentType: "application/json"
        )

        do {
            try httpClient.send(requestDescriptor)

            return .success
        }
        catch {

            return .failure
        }
    }

    public func forceFlush(explicitTimeout _: TimeInterval?) -> OpenTelemetrySdk.ExportResult {
        let semaphore = DispatchSemaphore(value: 0)

        httpClient.flush {
            semaphore.signal()
        }
        semaphore.wait()

        return .success
    }

    public func shutdown(explicitTimeout _: TimeInterval? = nil) {}


    // MARK: - Local override

    override func getFileKeyType() -> String {
        fileType ?? "logs"
    }
}
