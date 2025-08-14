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
import SwiftProtobuf


/// A base class that provides common functionality for OTLP exporters that use background HTTP requests.
///
/// This class handles disk storage, request creation, and recovery of stalled uploads.
public class OTLPBackgroundHTTPBaseExporter {

    // MARK: - Private

    let fileType: String?


    // MARK: - Internal

    /// The URL endpoint where data will be sent.
    let endpoint: URL

    /// The client responsible for handling background HTTP requests and disk storage.
    let httpClient: BackgroundHTTPClient

    /// Optional HTTP headers to be added to requests, typically derived from environment variables.
    let envVarHeaders: [(String, String)]?

    /// The OTLP configuration settings, such as timeout values.
    let config: OtlpConfiguration

    /// The storage mechanism for caching requests on disk before they are sent.
    let diskStorage: DiskStorage


    // MARK: - Initialization

    /// Initializes the base exporter with the necessary configuration.
    /// - Parameters:
    ///   - endpoint: The URL endpoint for data submission.
    ///   - config: The OTLP configuration settings.
    ///   - qosConfig: The Quality of Service settings for the background network session.
    ///   - envVarHeaders: Optional HTTP headers to add to each request.
    ///   - diskStorage: The disk storage instance for caching request data.
    ///   - fileType: An optional string to differentiate file types in storage, used for constructing storage keys.
    public init(
        endpoint: URL,
        config: OtlpConfiguration = OtlpConfiguration(),
        qosConfig: SessionQOSConfiguration,
        envVarHeaders: [(String, String)]? = EnvVarHeaders.attributes,
        diskStorage: DiskStorage = FilesystemDiskStorage(
            prefix: FilesystemPrefix(module: "OTLPBackgroundExporter"),
            rules: Rules(
                relativeUsedSize: 0.2,
                absoluteUsedSize: .init(value: 200, unit: .megabytes)
            ),
            encryption: NoneEncryption()
        ),
        fileType: String? = nil
    ) {
        self.envVarHeaders = envVarHeaders
        self.endpoint = endpoint
        self.config = config
        self.diskStorage = diskStorage
        self.fileType = fileType

        httpClient = BackgroundHTTPClient(sessionQosConfiguration: qosConfig, diskStorage: diskStorage)

        // Get incomplete requests and check for stalled files
        // Wait arbitrary 5 - 8s to clean caches content from abandoned or stalled files
        let cleanTime = DispatchTime.now() + .seconds(Int.random(in: 5 ... 8))

        DispatchQueue.global(qos: .utility).asyncAfter(deadline: cleanTime) { [weak self] in
            self?.httpClient.getAllSessionsTasks { [weak self] tasks in
                self?.checkStalledUploadsOperation(tasks: tasks)
            }
        }
    }


    // MARK: - Request method

    /// Creates a new `URLRequest` configured for sending OTLP protobuf data.
    /// - Parameter endpoint: The URL for the request.
    /// - Returns: A configured `URLRequest` instance.
    public func createRequest(endpoint: URL) -> URLRequest {
        var request = URLRequest(url: endpoint)

        request.httpMethod = "POST"
        request.setValue(Headers.getUserAgentHeader(), forHTTPHeaderField: Constants.HTTP.userAgent)
        request.setValue("application/x-protobuf", forHTTPHeaderField: "Content-Type")

        return request
    }


    // MARK: - Stalled request operations

    private func checkStalledUploadsOperation(tasks: [URLSessionTask]) {
        // Get ids from all incomplete requests
        let taskDescriptions = tasks
            .compactMap { $0.taskDescription }
            .compactMap {
                try? JSONDecoder().decode(RequestDescriptor.self, from: Data($0.utf8))
            }

        guard let uploadList = try? diskStorage.list(forKey: getStorageKey()) else {

            return
        }

        for file in uploadList {

            // If there is no upload task for file in cache folder, create RequestDescriptor and plan its upload to server
            // Note:
            //      File names are UUIDs of tasks
            if
                let requestId = UUID(uuidString: file.key),
                let taskDescription = taskDescriptions.first(where: { $0.id == requestId }) {
                let requestDescriptor = RequestDescriptor(
                    id: requestId,
                    endpoint: endpoint,
                    explicitTimeout: config.timeout,
                    fileKeyType: taskDescription.fileKeyType
                )

                try? httpClient.send(requestDescriptor)
            }
        }
    }


    // MARK: - Helper functions

    func getStorageKey() -> KeyBuilder {
        KeyBuilder.uploadsKey.append(getFileKeyType())
    }

    func getFileKeyType() -> String {
        fileType ?? "base"
    }
}
