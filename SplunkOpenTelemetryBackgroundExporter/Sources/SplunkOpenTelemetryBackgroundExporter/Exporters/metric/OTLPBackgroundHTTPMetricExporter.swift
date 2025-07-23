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

public class OTLPBackgroundHTTPMetricExporter: OTLPBackgroundHTTPBaseExporter, MetricExporter {

    // MARK: - Implementation StableMetricExporter protocol

    public func export(metrics: [MetricData]) -> ExportResult {
        let body = Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceRequest.with {
            $0.resourceMetrics = MetricsAdapter.toProtoResourceMetrics(metricData: metrics)
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

            return .failure
        }
    }

    public func flush() -> ExportResult {
        let semaphore = DispatchSemaphore(value: 0)

        httpClient.flush {
            semaphore.signal()
        }
        semaphore.wait()

        return .success
    }

    public func shutdown() -> ExportResult {
        return .success
    }

    public func getAggregationTemporality(for instrument: OpenTelemetrySdk.InstrumentType) -> OpenTelemetrySdk.AggregationTemporality {
        return .delta
    }

    // MARK: - Local override

    override func getFileKeyType() -> String {
        fileType ?? "metric"
    }
}
