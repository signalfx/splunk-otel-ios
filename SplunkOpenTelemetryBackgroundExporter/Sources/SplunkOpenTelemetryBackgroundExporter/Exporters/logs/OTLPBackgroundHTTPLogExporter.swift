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

public class OTLPBackgroundHTTPLogExporter: OTLPBackgroundHTTPBaseExporter, LogRecordExporter {

    // MARK: - Implementation LogRecordExporter protocol

    public func export(logRecords: [OpenTelemetrySdk.ReadableLogRecord], explicitTimeout: TimeInterval? = nil) -> OpenTelemetrySdk.ExportResult {
        let body = Opentelemetry_Proto_Collector_Logs_V1_ExportLogsServiceRequest.with { request in
            request.resourceLogs = LogRecordAdapter.toProtoResourceRecordLog(logRecordList: logRecords)
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

    public func forceFlush(explicitTimeout: TimeInterval?) -> OpenTelemetrySdk.ExportResult {
        let semaphore = DispatchSemaphore(value: 0)

        httpClient.flush {
            semaphore.signal()
        }
        semaphore.wait()

        return .success
    }

    public func shutdown(explicitTimeout: TimeInterval? = nil) {}
}
