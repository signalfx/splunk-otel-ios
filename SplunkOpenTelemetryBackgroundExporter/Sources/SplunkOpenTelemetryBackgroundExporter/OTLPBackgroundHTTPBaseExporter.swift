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

/// Basic implementation of exporters
public class OTLPBackgroundHTTPBaseExporter {

    // MARK: - Public

    let endpoint: URL
    let httpClient: BackgroundHTTPClient
    let envVarHeaders: [(String, String)]?
    let config: OtlpConfiguration


    // MARK: - Initialization

    public init(
        endpoint: URL,
        config: OtlpConfiguration = OtlpConfiguration(),
        qosConfig: SessionQOSConfiguration,
        envVarHeaders: [(String, String)]? = EnvVarHeaders.attributes
    ) {
        self.envVarHeaders = envVarHeaders
        self.endpoint = endpoint
        self.config = config

        httpClient = BackgroundHTTPClient(sessionQosConfiguration: qosConfig)

        // Get incomplete requests and check for stalled files
        httpClient.getAllSessionsTasks { [weak self] tasks in
            self?.checkStalledUploadsOperation(tasks: tasks)
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

        // Get enumerator for all files in cache folder
        guard let uploadsCacheFilesEnumerator = getCacheEnumerator() else {
            return
        }

        // Enumerate files in cache folder
        for case let fileUrl as URL in uploadsCacheFilesEnumerator {
            guard 
                let fileName = fetchFileName(for: fileUrl),
                let requestId = UUID(uuidString: fileName)
            else {                
                continue
            }

            // If there is no upload task for file in cache folder, create RequestDescriptor and plan its upload to server
            // Note:
            //      File names are UUIDs of tasks
            if !taskIdentifiers.contains(where: { $0.uuidString == fileName }) {
                let requestDescriptor = RequestDescriptor(
                    id: requestId,
                    endpoint: endpoint,
                    explicitTimeout: config.timeout
                )

                httpClient.send(requestDescriptor)
            }
        }
    }

    func fetchFileName(for file: URL) -> String? {
        let fileProperties = try? file.resourceValues(forKeys: [.nameKey])
        return fileProperties?.name
    }

    func getCacheEnumerator() -> FileManager.DirectoryEnumerator? {
        // Get folder where to upload files are stored
        guard let uploadsCacheFolder = DiskCache.cache(subfolder: .uploadFiles) else {
            return nil
        }

        // Get enumerator for all stalled files
        let propertyKeys: [URLResourceKey] = [.nameKey]

        return FileManager.default.enumerator(
            at: uploadsCacheFolder,
            includingPropertiesForKeys: propertyKeys,
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants],
            errorHandler: nil
        )
    }
}
