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

public class OTLPBackgroundHTTPTraceExporter: OTLPBackgroundHTTPBaseExporter, SpanExporter {

    // MARK: - Implementation SpanExporter protocol

    public func export(spans: [SpanData], explicitTimeout: TimeInterval? = nil) -> SpanExporterResultCode {
        // Convert spans to OTLP JSON models using our custom adapter
        let resourceSpans = SpanDataAdapter.toResourceSpans(spans)

        // Skip if no spans to export (filter empty envelopes per OTLP spec)
        guard !resourceSpans.isEmpty else {
            return .success
        }

        let request = OTLPExportTraceServiceRequest(resourceSpans: resourceSpans)
        let requestId = UUID()

        do {
            // Encode to JSON instead of protobuf binary
            let encoder = JSONEncoder()
            encoder.nonConformingFloatEncodingStrategy = .convertToString(
                positiveInfinity: "Infinity",
                negativeInfinity: "-Infinity",
                nan: "NaN"
            )
            let storeData = try encoder.encode(request)

            // If no endpoint is configured, store in pending folder for later
            if isPendingEndpoint {
                try storePendingData(storeData, requestId: requestId)
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
            // The batch is already durable in active storage. Report success so upstream in-memory
            // processors do not re-encode and enqueue duplicate span files; stalled upload recovery
            // or a later endpoint flush will retry the persisted file.
            return .success
        }
    }

    public func flush(explicitTimeout: TimeInterval? = nil) -> SpanExporterResultCode {
        flushHTTPClient(explicitTimeout: explicitTimeout) ? .success : .failure
    }

    public func shutdown(explicitTimeout _: TimeInterval? = nil) {}


    // MARK: - Local override

    override func getFileKeyType() -> String {
        fileType ?? "trace"
    }
}
