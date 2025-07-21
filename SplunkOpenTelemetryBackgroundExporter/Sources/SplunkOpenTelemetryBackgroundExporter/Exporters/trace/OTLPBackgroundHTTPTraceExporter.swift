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

/// An implementation of the `SpanExporter` that exports traces to an OTLP/HTTP endpoint.
///
/// This exporter is designed for background operation. It first saves trace data to disk and then
/// uses a background `URLSession` to upload the data. This approach ensures that data is not lost
/// if the app is suspended or terminated before the upload is complete.
public class OTLPBackgroundHTTPTraceExporter: OTLPBackgroundHTTPBaseExporter, SpanExporter {

    // MARK: - Implementation SpanExporter protocol

    /// Exports a batch of spans by serializing them and saving them to disk for asynchronous background upload.
    ///
    /// This method returns `.success` if the spans are successfully written to a temporary file. The actual
    /// HTTP upload is managed by a background `URLSession` and will be attempted later, even if the
    /// app is suspended.
    ///
    /// - Parameters:
    ///   - spans: An array of `SpanData` to be exported.
    ///   - explicitTimeout: An optional timeout. This is used to ensure the disk write operation completes
    ///     within a reasonable time, but it does not apply to the background network request.
    /// - Returns: `.success` if the data is successfully persisted to disk for later upload; otherwise, `.failure`.
    public func export(spans: [SpanData], explicitTimeout: TimeInterval? = nil) -> SpanExporterResultCode {
        let body = Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceRequest.with {
            $0.resourceSpans = SpanAdapter.toProtoResourceSpans(spanDataList: spans)
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

    /// Forces any pending data to be submitted for upload.
    ///
    /// This method blocks the current thread until the background `URLSession` has been flushed,
    /// ensuring that all previously queued data has been processed.
    ///
    /// - Parameter explicitTimeout: This parameter is ignored in the current implementation.
    /// - Returns: Always returns `.success`.
    public func flush(explicitTimeout: TimeInterval? = nil) -> SpanExporterResultCode {
        let semaphore = DispatchSemaphore(value: 0)

        httpClient.flush {
            semaphore.signal()
        }
        semaphore.wait()

        return .success
    }

    /// Shuts down the exporter.
    ///
    /// - Note: This method is a no-op in the current implementation. The background `URLSession`
    ///   is managed by the operating system and will continue to attempt uploads even after
    ///   the application is suspended.
    ///
    /// - Parameter explicitTimeout: This parameter is ignored.
    public func shutdown(explicitTimeout: TimeInterval? = nil) {}


    // MARK: - Local override

    override func getFileKeyType() -> String {
        fileType ?? "trace"
    }
}
