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

/// An implementation of the `MetricExporter` that exports metrics to an OTLP/HTTP endpoint.
///
/// This exporter is designed for background operation. It first saves metric data to disk and then
/// uses a background `URLSession` to upload the data. This approach ensures that data is not lost

/// if the app is suspended or terminated before the upload is complete.
public class OTLPBackgroundHTTPMetricExporter: OTLPBackgroundHTTPBaseExporter, MetricExporter {

    // MARK: - Implementation MetricExporter protocol

    /// Exports a batch of metrics by serializing them and saving them to disk for asynchronous background upload.
    ///
    /// This method returns `.success` if the metrics are successfully written to a temporary file. The actual
    /// HTTP upload is managed by a background `URLSession` and will be attempted later, even if the
    /// app is suspended.
    ///
    /// - Parameters:
    ///   - metrics: An array of `Metric` data to be exported.
    ///   - shouldCancel: An optional closure to check if the export operation should be cancelled. This is not used in this implementation.
    /// - Returns: `.success` if the data is successfully persisted to disk for later upload; otherwise, `.failureNotRetryable`.
    public func export(metrics: [Metric], shouldCancel: (() -> Bool)?) -> MetricExporterResultCode {
        let body = Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceRequest.with {
            $0.resourceMetrics = MetricsAdapter.toProtoResourceMetrics(metricDataList: metrics)
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

            return .failureNotRetryable
        }

        let requestDescriptor = RequestDescriptor(
            id: requestId,
            endpoint: endpoint,
            explicitTimeout: config.timeout,
            fileKeyType: getFileKeyType()
        )

        do {
            try httpClient.send(requestDescriptor)

            return .success
        } catch {

            return .failureNotRetryable
        }
    }

    /// Forces any pending data to be submitted for upload.
    ///
    /// This method blocks the current thread until the background `URLSession` has been flushed,
    /// ensuring that all previously queued data has been processed.
    ///
    /// - Parameter explicitTimeout: This parameter is ignored in the current implementation.
    /// - Returns: Always returns `.success`.
    public func forceFlush(explicitTimeout: TimeInterval?) -> OpenTelemetrySdk.ExportResult {
        let semaphore = DispatchSemaphore(value: 0)

        httpClient.flush {
            semaphore.signal()
        }
        semaphore.wait()

        return .success
    }


    // MARK: - Local override

    override func getFileKeyType() -> String {
        fileType ?? "metric"
    }
}
