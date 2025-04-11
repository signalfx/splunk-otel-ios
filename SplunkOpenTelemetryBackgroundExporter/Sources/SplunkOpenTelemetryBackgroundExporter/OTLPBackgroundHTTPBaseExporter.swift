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
import SwiftProtobuf
import Foundation
import CiscoDiskStorage
import CiscoEncryption

/// Basic implementation of exporters
public class OTLPBackgroundHTTPBaseExporter {

    // MARK: - Public

    let endpoint: URL
    let httpClient: BackgroundHTTPClient
    let envVarHeaders: [(String, String)]?
    let config: OtlpConfiguration
    let diskStorage: DiskStorage


    // MARK: - Initialization

    public init(
        endpoint: URL,
        config: OtlpConfiguration = OtlpConfiguration(),
        qosConfig: SessionQOSConfiguration,
        envVarHeaders: [(String, String)]? = EnvVarHeaders.attributes,
        diskStorage: DiskStorage = FilesystemDiskStorage(
            prefix: FilesystemPrefix(module: "OTLPBackgroundExporter"),
            rules: Rules.default,
            encryption: NoneEncryption()
        )
    ) {
        self.envVarHeaders = envVarHeaders
        self.endpoint = endpoint
        self.config = config
        self.diskStorage = diskStorage

        httpClient = BackgroundHTTPClient(sessionQosConfiguration: qosConfig, diskStorage: diskStorage)

        // Get incomplete requests and check for stalled files
        // Wait arbitrary 5 - 8s to clean caches content from abandoned or stalled files.
        let cleanTime = DispatchTime.now() + .seconds(Int.random(in: 5 ... 8))

        DispatchQueue.global(qos: .utility).asyncAfter(deadline: cleanTime) { [weak self] in
            self?.httpClient.getAllSessionsTasks { [weak self] tasks in
                self?.checkStalledUploadsOperation(tasks: tasks)
            }
        }
    }

    // MARK: - Request method

    public func createRequest(endpoint: URL) -> URLRequest {
        var request = URLRequest(url: endpoint)

        request.httpMethod = "POST"
        request.setValue(Headers.getUserAgentHeader(), forHTTPHeaderField: Constants.HTTP.userAgent)
        request.setValue("application/x-protobuf", forHTTPHeaderField: "Content-Type")

        return request
    }


    // MARK: - Stalled request operations

    func checkStalledUploadsOperation(tasks: [URLSessionTask]) {
        // Get ids from all incomplete requests
        let taskIdentifiers = tasks
            .compactMap { $0.taskDescription }
            .compactMap {
                try? JSONDecoder().decode(RequestDescriptor.self, from: Data($0.utf8))
            }
            .compactMap { $0.id }

        guard let uploadList = try? diskStorage.list(forKey: KeyBuilder.uploadsKey) else {

            return
        }

        for file in uploadList {

            // If there is no upload task for file in cache folder, create RequestDescriptor and plan its upload to server
            // Note:
            //      File names are UUIDs of tasks
            if
                let requestId = UUID(uuidString: file.key),
                !taskIdentifiers.contains(where: { $0 == requestId })
            {
                let requestDescriptor = RequestDescriptor(
                    id: requestId,
                    endpoint: endpoint,
                    explicitTimeout: config.timeout
                )

                try? httpClient.send(requestDescriptor)
            }
        }
    }
}
