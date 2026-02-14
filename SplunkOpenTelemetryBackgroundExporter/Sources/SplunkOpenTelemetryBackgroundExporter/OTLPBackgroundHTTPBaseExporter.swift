//
/*
Copyright 2026 Splunk Inc.

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

/// Basic implementation of exporters.
public class OTLPBackgroundHTTPBaseExporter {

    // MARK: - Private

    private let qosConfig: SessionQOSConfiguration
    private let performStalledUploadCheck: Bool

    /// Lock for thread-safe access to mutable endpoint state.
    private let stateLock = NSLock()

    /// Backing storage for endpoint (access via thread-safe computed property).
    private var _endpoint: URL?

    /// Backing storage for additional headers (access via thread-safe computed property).
    private var _additionalHeaders: [String: String]


    // MARK: - Internal

    let fileType: String?
    let envVarHeaders: [(String, String)]?
    let config: OTLPExporterConfiguration
    let diskStorage: DiskStorage
    var checkStalledTask: Task<Void, Never>?

    /// Thread-safe accessor for the endpoint URL.
    var endpoint: URL? {
        get {
            stateLock.lock()
            defer { stateLock.unlock() }
            return _endpoint
        }
        set {
            stateLock.lock()
            defer { stateLock.unlock() }
            _endpoint = newValue
        }
    }

    /// Thread-safe accessor for additional headers.
    var additionalHeaders: [String: String] {
        get {
            stateLock.lock()
            defer { stateLock.unlock() }
            return _additionalHeaders
        }
        set {
            stateLock.lock()
            defer { stateLock.unlock() }
            _additionalHeaders = newValue
        }
    }

    lazy var httpClient: BackgroundHTTPClientProtocol = BackgroundHTTPClient(
        sessionQosConfiguration: qosConfig,
        diskStorage: diskStorage,
        namespace: getFileKeyType()
    )


    // MARK: - Public Properties

    /// Returns `true` if no endpoint is configured and data should be cached to pending storage.
    public var isPendingEndpoint: Bool {
        endpoint == nil
    }


    // MARK: - Initialization

    public init(
        endpoint: URL?,
        config: OTLPExporterConfiguration = OTLPExporterConfiguration(),
        qosConfig: SessionQOSConfiguration,
        envVarHeaders: [(String, String)]? = OTLPEnvVarHeaders.attributes,
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
        _additionalHeaders = headers
        _endpoint = endpoint
        self.config = config
        self.diskStorage = diskStorage
        self.fileType = fileType
        self.qosConfig = qosConfig
        self.performStalledUploadCheck = performStalledUploadCheck

        // Only start stalled upload check if endpoint is configured
        if performStalledUploadCheck, endpoint != nil {
            startStalledUploadCheck()
        }
    }

    deinit {
        checkStalledTask?.cancel()
    }


    // MARK: - Endpoint Management

    /// Updates the endpoint and flushes any pending data.
    ///
    /// - Parameters:
    ///   - newEndpoint: The new endpoint URL.
    ///   - newHeaders: Optional new headers to use (e.g., for access token).
    public func setEndpoint(_ newEndpoint: URL, headers newHeaders: [String: String]? = nil) {
        // Update state atomically
        stateLock.lock()
        _endpoint = newEndpoint
        if let newHeaders {
            _additionalHeaders = newHeaders
        }
        stateLock.unlock()

        // Flush any pending data now that we have an endpoint
        flushPendingData()

        // Start stalled upload check now that we have an endpoint
        if performStalledUploadCheck {
            startStalledUploadCheck()
        }
    }

    /// Clears the endpoint, causing new data to be cached to pending storage.
    ///
    /// This is useful when you want to temporarily disable sending data
    /// but still cache it for later transmission.
    public func clearEndpoint() {
        // Cancel any pending stalled upload checks
        checkStalledTask?.cancel()
        checkStalledTask = nil

        // Clear the endpoint - new data will go to pending storage
        endpoint = nil
    }

    /// Starts the background task to check for stalled uploads.
    private func startStalledUploadCheck() {
        // Cancel any existing check
        checkStalledTask?.cancel()

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

    /// Flushes any data stored in pending storage by moving it to active storage and scheduling uploads.
    private func flushPendingData() {
        // Capture current state atomically
        let (currentEndpoint, currentHeaders) = getEndpointState()

        guard let currentEndpoint else {
            return
        }

        // Get all pending files
        guard let pendingFiles = try? diskStorage.list(forKey: getPendingStorageKey()) else {
            return
        }

        // Move each pending file to active storage and schedule for upload
        for fileInfo in pendingFiles {
            let pendingKey = KeyBuilder(
                fileInfo.key,
                parrentKeyBuilder: getPendingStorageKey()
            )

            let activeKey = KeyBuilder(
                fileInfo.key,
                parrentKeyBuilder: getStorageKey()
            )

            do {
                // Get pending file URL
                let pendingFileUrl = try diskStorage.finalDestination(forKey: pendingKey)

                // Read data from pending storage
                let data = try Data(contentsOf: pendingFileUrl)

                // Write to active storage
                try diskStorage.insert(data, forKey: activeKey)

                // Delete from pending storage
                try diskStorage.delete(forKey: pendingKey)

                // Create request descriptor and schedule upload
                guard let requestId = UUID(uuidString: fileInfo.key) else {
                    continue
                }

                let requestDescriptor = RequestDescriptor(
                    id: requestId,
                    endpoint: currentEndpoint,
                    explicitTimeout: config.timeout,
                    fileKeyType: getFileKeyType(),
                    headers: buildHeaders(from: currentHeaders)
                )

                try httpClient.send(requestDescriptor)
            }
            catch {
                // If we fail to move/send one file, continue with others
                continue
            }
        }
    }


    // MARK: - Stalled request operations

    func checkStalledUploadsOperation(tasks: [URLSessionTask]) {
        // Capture current endpoint atomically
        guard let currentEndpoint = endpoint else {
            return
        }

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
        // to handle endpoint configuration changes.
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
                descriptor.endpoint != currentEndpoint
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
        // Capture current state atomically
        let (currentEndpoint, currentHeaders) = getEndpointState()

        guard let currentEndpoint else {
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
            if let existingTaskDescription = allTaskDescriptions.first(where: { $0.id == requestId }) {
                // Resend if the task was cancelled (stalled or had mismatched endpoint)
                if cancelledTaskIds.contains(requestId) {
                    // Create a new RequestDescriptor with the current endpoint to handle endpoint changes.
                    // This ensures cached data is sent to the updated endpoint, not the old one.
                    let taskDescription = RequestDescriptor(
                        id: requestId,
                        endpoint: currentEndpoint,
                        explicitTimeout: config.timeout,
                        fileKeyType: getFileKeyType(),
                        headers: buildHeaders(from: currentHeaders)
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
                    endpoint: currentEndpoint,
                    explicitTimeout: config.timeout,
                    fileKeyType: getFileKeyType(),
                    headers: buildHeaders(from: currentHeaders)
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

    /// Returns the current endpoint and headers atomically.
    private func getEndpointState() -> (endpoint: URL?, headers: [String: String]) {
        stateLock.lock()
        defer { stateLock.unlock() }
        return (_endpoint, _additionalHeaders)
    }

    /// Builds combined headers from additional headers and environment variable headers.
    private func buildHeaders(from additionalHeaders: [String: String]) -> [String: String] {
        var combinedHeaders = additionalHeaders

        if let envVarHeaders {
            for (key, value) in envVarHeaders {
                combinedHeaders[key] = value
            }
        }

        return combinedHeaders
    }

    var headers: [String: String] {
        buildHeaders(from: additionalHeaders)
    }
}
