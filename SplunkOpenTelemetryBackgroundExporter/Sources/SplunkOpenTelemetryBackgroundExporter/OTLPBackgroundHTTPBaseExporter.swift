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

/// Basic implementation of exporters.
public class OTLPBackgroundHTTPBaseExporter {

    // MARK: - Private

    private let qosConfig: SessionQOSConfiguration


    // MARK: - Internal

    let fileType: String?
    var endpoint: URL?
    let envVarHeaders: [(String, String)]?
    var additionalHeaders: [String: String]
    let config: OtlpConfiguration
    let diskStorage: DiskStorage
    var checkStalledTask: Task<Void, Never>?

    var httpClient: BackgroundHTTPClientProtocol


    // MARK: - Initialization

    public init(
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
        self.envVarHeaders = envVarHeaders
        additionalHeaders = headers
        self.endpoint = endpoint
        self.config = config
        self.diskStorage = diskStorage
        self.fileType = fileType
        self.qosConfig = qosConfig
        self.httpClient = httpClient ?? BackgroundHTTPClient(
            sessionQosConfiguration: qosConfig,
            diskStorage: diskStorage,
            namespace: getFileKeyType()
        )

        if endpoint != nil {
            flushPendingData()
        }

        if performStalledUploadCheck && endpoint != nil {
            // Get incomplete requests and check for stalled files
            // Wait arbitrary 5 - 8s to clean caches content from abandoned or stalled files.
            checkStalledTask = Task.detached(priority: .utility) { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(Int.random(in: 5 ... 8) * 1_000_000_000))
                self?.httpClient
                    .getAllSessionsTasks { [weak self] tasks in
                        self?.checkStalledUploadsOperation(tasks: tasks)
                    }
            }
        }
    }

    deinit {
        checkStalledTask?.cancel()
    }


    // MARK: - Stalled request operations

    func checkStalledUploadsOperation(tasks: [URLSessionTask]) {

        // Get descriptions from all incomplete requests
        let allTaskDescriptions =
            tasks
            .compactMap(\.taskDescription)
            .compactMap {
                try? JSONDecoder().decode(RequestDescriptor.self, from: Data($0.utf8))
            }

        // Get time when all newly created tasks should be already sent.
        let cancelTime = Date(timeIntervalSinceNow: -1 * config.timeout)

        // Cancel all stalled tasks.
        let toCancelTasks = tasks.filter {
            guard let expectedExecutionDate = $0.earliestBeginDate else {
                return true
            }

            return expectedExecutionDate < cancelTime
        }

        for task in toCancelTasks {
            task.cancel()
        }

        // Get all file's keys that should be uploaded
        guard let uploadList = (try? diskStorage.list(forKey: getStorageKey()))?.map(\.key) else {

            return
        }

        checkAndSend(fileKeys: uploadList, existingTasks: allTaskDescriptions, cancelTime: cancelTime)
    }

    func checkAndSend(fileKeys files: [String], existingTasks allTaskDescriptions: [RequestDescriptorProtocol], cancelTime: Date) {
        // Skip if no endpoint is configured
        guard let endpoint else {
            return
        }

        // Go throught file list and try to send all files again.
        for fileKey in files {
            guard let requestId = UUID(uuidString: fileKey) else {

                continue
            }

            // If there is no upload task for file in cache folder, create RequestDescriptor and plan its upload to server
            // Note:
            //      File names are UUIDs of tasks
            if let taskDescription = allTaskDescriptions.first(where: { $0.id == requestId }) {
                // Perform send only for tasks which was scheduled in past and was cancelled in previous step.
                if taskDescription.scheduled < cancelTime {
                    try? httpClient.send(taskDescription)
                }
            }
            else {
                // This task was forgotten by system, create new one.
                let taskDescription = RequestDescriptor(
                    id: requestId,
                    endpoint: endpoint,
                    explicitTimeout: config.timeout,
                    fileKeyType: getFileKeyType(),
                    headers: headers
                )

                try? httpClient.send(taskDescription)
            }
        }
    }


    // MARK: - Helper functions

    func getStorageKey() -> KeyBuilder {
        KeyBuilder.uploadsKey.append(getFileKeyType())
    }

    func getPendingStorageKey() -> KeyBuilder {
        KeyBuilder.pendingUploadsKey.append(getFileKeyType())
    }

    func getFileKeyType() -> String {
        fileType ?? "base"
    }

    /// Returns `true` if no endpoint is configured and data should be cached.
    public var isPendingEndpoint: Bool {
        endpoint == nil
    }

    var headers: [String: String] {
        var combinedHeaders = additionalHeaders

        if let envVarHeaders {
            for (key, value) in envVarHeaders {
                combinedHeaders[key] = value
            }
        }

        return combinedHeaders
    }


    /// Flushes all pending cached data to the server.
    ///
    /// This method moves all data from the pending storage to the active upload queue.
    private func flushPendingData() {
        guard let endpoint else {
            return
        }

        // Get all pending files
        guard let pendingFiles = try? diskStorage.list(forKey: getPendingStorageKey()) else {
            return
        }

        // Move each pending file to active storage and schedule for upload
        for fileInfo in pendingFiles {
            guard let requestId = UUID(uuidString: fileInfo.key) else {
                continue
            }

            let pendingKey = KeyBuilder(
                requestId.uuidString,
                parrentKeyBuilder: getPendingStorageKey()
            )

            let activeKey = KeyBuilder(
                requestId.uuidString,
                parrentKeyBuilder: getStorageKey()
            )

            do {
                // Read data from pending storage
                guard let pendingFileUrl = try? diskStorage.finalDestination(forKey: pendingKey),
                      FileManager.default.fileExists(atPath: pendingFileUrl.path),
                      let data = try? Data(contentsOf: pendingFileUrl)
                else {
                    continue
                }

                // Write to active storage
                try diskStorage.insert(data, forKey: activeKey)

                // Delete from pending storage
                try diskStorage.delete(forKey: pendingKey)

                // Schedule upload
                let requestDescriptor = RequestDescriptor(
                    id: requestId,
                    endpoint: endpoint,
                    explicitTimeout: config.timeout,
                    fileKeyType: getFileKeyType(),
                    headers: headers
                )

                try httpClient.send(requestDescriptor)
            }
            catch {
                // Log error but continue processing other files
                continue
            }
        }
    }
}
