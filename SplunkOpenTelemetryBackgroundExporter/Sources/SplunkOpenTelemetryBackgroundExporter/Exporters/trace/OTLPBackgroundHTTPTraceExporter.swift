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
import CiscoEncryption
import Foundation
import OpenTelemetryProtocolExporterCommon
import OpenTelemetrySdk

public class OTLPBackgroundHTTPTraceExporter: OTLPBackgroundHTTPBaseExporter, SpanExporter {

    // MARK: - Initialization

    public override init(
        endpoint: URL?,
        config: OtlpConfiguration = OtlpConfiguration(),
        qosConfig: SessionQOSConfiguration,
        envVarHeaders: [(String, String)]? = EnvVarHeaders.attributes,
        headers: [String: String] = [:],
        diskStorage: DiskStorage = FilesystemDiskStorage(
            prefix: FilesystemPrefix(module: "OTLPBackgroundExporter"),
            rules: Rules(
                relativeUsedSize: 0.2,
                absoluteUsedSize: .init(value: 200, unit: .megabytes)
            ),
            encryption: NoneEncryption()
        ),
        fileType: String? = nil,
        performStalledUploadCheck: Bool = true,
        httpClient: BackgroundHTTPClientProtocol? = nil
    ) {
        super.init(
            endpoint: endpoint,
            config: config,
            qosConfig: qosConfig,
            envVarHeaders: envVarHeaders,
            headers: headers,
            diskStorage: diskStorage,
            fileType: fileType ?? "trace",
            performStalledUploadCheck: performStalledUploadCheck,
            httpClient: httpClient
        )
    }

    // MARK: - Implementation SpanExporter protocol

    public func export(spans: [SpanData], explicitTimeout: TimeInterval? = nil) -> SpanExporterResultCode {
        let body = Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceRequest.with {
            $0.resourceSpans = SpanAdapter.toProtoResourceSpans(spanDataList: spans)
        }

        let requestId = UUID()

        do {
            let storeData = try body.serializedData()

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

            // Normal flow - store and send immediately
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

        guard let endpoint else {
            return .failure
        }

        let timeout = min(explicitTimeout ?? TimeInterval.greatestFiniteMagnitude, config.timeout)

        let requestDescriptor = RequestDescriptor(
            id: requestId,
            endpoint: endpoint,
            explicitTimeout: timeout,
            fileKeyType: getFileKeyType(),
            headers: headers
        )

        do {
            try httpClient.send(requestDescriptor)

            return .success
        }
        catch {

            return .failure
        }
    }

    public func flush(explicitTimeout _: TimeInterval? = nil) -> SpanExporterResultCode {
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
        fileType ?? "trace"
    }
}
