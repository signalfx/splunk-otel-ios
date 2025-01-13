//
/*
Copyright 2024 Splunk Inc.

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

import OpenTelemetryProtocolExporterCommon
import OpenTelemetrySdk
import Foundation

public class OTLPBackgroundHTTPMetricExporter: OTLPBackgroundHTTPBaseExporter, MetricExporter {

    // MARK: - Implementation MetricExporter protocol

    public func export(metrics: [Metric], shouldCancel: (() -> Bool)?) -> MetricExporterResultCode {
        let body = Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceRequest.with {
            $0.resourceMetrics = MetricsAdapter.toProtoResourceMetrics(metricDataList: metrics)
        }

        let requestId = UUID()

        guard
            DiskCache.checkDiskSpaceAndIntegrity(),
            let url = DiskCache.cache(subfolder: .uploadFiles, item: requestId.uuidString)
        else {
            return .failureNotRetryable
        }

        do {
            let storeData = try body.serializedData()
            try storeData.write(to: url)
        } catch {
            return .failureNotRetryable
        }

        DiskCache.refreshStatistics()

        let requestDescriptor = RequestDescriptor(
            id: requestId,
            endpoint: endpoint,
            explicitTimeout: config.timeout
        )

        httpClient.send(requestDescriptor)

        return .success
    }

    public func forceFlush(explicitTimeout: TimeInterval?) -> OpenTelemetrySdk.ExportResult {
        let semaphore = DispatchSemaphore(value: 0)

        httpClient.flush {
            semaphore.signal()
        }
        semaphore.wait()

        return .success
    }
}
