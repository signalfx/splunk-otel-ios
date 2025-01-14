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

public class OTLPBackgroundHTTPTraceExporter: OTLPBackgroundHTTPBaseExporter, SpanExporter {

    // MARK: - Implementation SpanExporter protocol

    public func export(spans: [SpanData], explicitTimeout: TimeInterval? = nil) -> SpanExporterResultCode {
        let body = Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceRequest.with {
            $0.resourceSpans = SpanAdapter.toProtoResourceSpans(spanDataList: spans)
        }

        let requestId = UUID()

        guard
            DiskCache.checkDiskSpaceAndIntegrity(),
            let url = DiskCache.cache(subfolder: .uploadFiles, item: requestId.uuidString)
        else {
            return .failure
        }

        do {
            let storeData = try body.serializedData()
            try storeData.write(to: url)
        } catch {
            return .failure
        }

        DiskCache.refreshStatistics()

        let timeout = min(explicitTimeout ?? TimeInterval.greatestFiniteMagnitude, config.timeout)

        let requestDescriptor = RequestDescriptor(
            id: requestId,
            endpoint: endpoint,
            explicitTimeout: timeout
        )

        httpClient.send(requestDescriptor)

        return .success
    }

    public func flush(explicitTimeout: TimeInterval? = nil) -> SpanExporterResultCode {
        let semaphore = DispatchSemaphore(value: 0)

        httpClient.flush {
            semaphore.signal()
        }
        semaphore.wait()

        return .success
    }

    public func shutdown(explicitTimeout: TimeInterval? = nil) {}
}
