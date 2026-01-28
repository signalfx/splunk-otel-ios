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
    let endpoint: URL
    let envVarHeaders: [(String, String)]?
    let additionalHeaders: [String: String]
    let config: OtlpConfiguration
    let diskStorage: DiskStorage
    var checkStalledTask: Task<Void, Never>?

    lazy var httpClient: BackgroundHTTPClientProtocol = BackgroundHTTPClient(
        sessionQosConfiguration: qosConfig,
        diskStorage: diskStorage,
        namespace: getFileKeyType()
    )


    // MARK: - Initialization

    public init(
        endpoint: URL,
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
        performStalledUploadCheck: Bool = true
    ) {
        self.envVarHeaders = envVarHeaders
        additionalHeaders = headers
        self.endpoint = endpoint
        self.config = config
        self.diskStorage = diskStorage
        self.fileType = fileType
        self.qosConfig = qosConfig

        if performStalledUploadCheck {
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

        // Cancel stalled tasks (scheduled in the past or no date) and tasks with mismatched endpoints.
        // Tasks with different endpoints need to be cancelled and recreated with the current endpoint
        // to handle endpoint configuration changes (e.g., caching mode -> real endpoint).
        let toCancelTasks = tasks.filter { task in
            // Cancel if stalled (no earliestBeginDate or scheduled in the past)
            guard let expectedExecutionDate = task.earliestBeginDate else {
                return true
            }

            if expectedExecutionDate < cancelTime {
                return true
            }

            // Also cancel if the task is pointing to a different endpoint (endpoint changed)
            // Only check this if we can decode the task description
            if let taskDescription = task.taskDescription,
                let descriptor = try? JSONDecoder().decode(RequestDescriptor.self, from: Data(taskDescription.utf8)),
                descriptor.endpoint != endpoint
            {
                return true
            }

            return false
        }

        // Build set of cancelled task IDs to track which files need to be resent
        let cancelledTaskIds = Set(
            toCancelTasks.compactMap { task -> UUID? in
                guard let taskDescription = task.taskDescription,
                      let descriptor = try? JSONDecoder().decode(RequestDescriptor.self, from: Data(taskDescription.utf8))
                else {
                    return nil
                }

                return descriptor.id
            }
        )

        for task in toCancelTasks {
            task.cancel()
        }

        // Get all file's keys that should be uploaded
        guard let uploadList = (try? diskStorage.list(forKey: getStorageKey()))?.map(\.key) else {

            return
        }

        checkAndSend(fileKeys: uploadList, existingTasks: allTaskDescriptions, cancelledTaskIds: cancelledTaskIds)
    }

    func checkAndSend(fileKeys files: [String], existingTasks allTaskDescriptions: [RequestDescriptorProtocol], cancelledTaskIds: Set<UUID>) {

        // Go throught file list and try to send all files again.
        for fileKey in files {
            guard let requestId = UUID(uuidString: fileKey) else {

                continue
            }

            // If there is no upload task for file in cache folder, create RequestDescriptor and plan its upload to server
            // Note:
            //      File names are UUIDs of tasks
            if let existingTaskDescription = allTaskDescriptions.first(where: { $0.id == requestId }) {
                // Resend if the task was cancelled (stalled or had mismatched endpoint)
                if cancelledTaskIds.contains(requestId) {
                    // Create a new RequestDescriptor with the current endpoint to handle endpoint changes.
                    // This ensures cached data is sent to the updated endpoint, not the old one.
                    let taskDescription = RequestDescriptor(
                        id: requestId,
                        endpoint: endpoint,
                        explicitTimeout: config.timeout,
                        fileKeyType: getFileKeyType(),
                        headers: headers
                    )

                    try? httpClient.send(taskDescription)
                }
                // If not cancelled, the existing task will continue with its current endpoint
                // (which should match our endpoint since we cancel mismatched ones)
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

    func getFileKeyType() -> String {
        fileType ?? "base"
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
}
