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
    private let stateLock = NSLock()
    private var storedEndpoint: URL?
    private var storedAdditionalHeaders: [String: String]

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
            return storedEndpoint
        }
        set {
            stateLock.lock()
            defer { stateLock.unlock() }
            storedEndpoint = newValue
        }
    }

    /// Thread-safe accessor for additional headers.
    var additionalHeaders: [String: String] {
        get {
            stateLock.lock()
            defer { stateLock.unlock() }
            return storedAdditionalHeaders
        }
        set {
            stateLock.lock()
            defer { stateLock.unlock() }
            storedAdditionalHeaders = newValue
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
        storedAdditionalHeaders = headers
        storedEndpoint = endpoint
        self.config = config
        self.diskStorage = diskStorage
        self.fileType = fileType
        self.qosConfig = qosConfig
        self.performStalledUploadCheck = performStalledUploadCheck

        if performStalledUploadCheck, endpoint != nil {
            startStalledUploadCheck()
        }
    }

    deinit {
        checkStalledTask?.cancel()
    }

    // MARK: - Endpoint Management

    /// Updates the endpoint and flushes any pending data.
    /// - Parameters:
    ///   - newEndpoint: The new endpoint URL.
    ///   - newHeaders: Optional new headers to use (e.g., for access token).
    public func setEndpoint(_ newEndpoint: URL, headers newHeaders: [String: String]? = nil) {
        stateLock.lock()
        storedEndpoint = newEndpoint
        if let newHeaders {
            storedAdditionalHeaders = newHeaders
        }
        stateLock.unlock()

        flushPendingData()

        if performStalledUploadCheck {
            startStalledUploadCheck()
        }
    }

    /// Clears the endpoint, causing new data to be cached to pending storage.
    public func clearEndpoint() {
        checkStalledTask?.cancel()
        checkStalledTask = nil
        endpoint = nil
    }

    private func startStalledUploadCheck() {
        checkStalledTask?.cancel()
        // Wait 5-8s to clean caches content from abandoned or stalled files.
        checkStalledTask = Task.detached(priority: .utility) { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Int.random(in: 5 ... 8) * 1_000_000_000))
            self?.httpClient.getAllSessionsTasks { [weak self] tasks in
                self?.checkStalledUploadsOperation(tasks: tasks)
            }
        }
    }

    /// Flushes any data stored in pending storage by moving it to active storage and scheduling uploads.
    private func flushPendingData() {
        let (currentEndpoint, currentHeaders) = getEndpointState()
        guard let currentEndpoint else {
            return
        }

        guard let pendingFiles = try? diskStorage.list(forKey: getPendingStorageKey()) else {
            return
        }

        for fileInfo in pendingFiles {
            let pendingKey = KeyBuilder(fileInfo.key, parrentKeyBuilder: getPendingStorageKey())
            let activeKey = KeyBuilder(fileInfo.key, parrentKeyBuilder: getStorageKey())

            do {
                let pendingFileUrl = try diskStorage.finalDestination(forKey: pendingKey)
                let data = try Data(contentsOf: pendingFileUrl)
                try diskStorage.insert(data, forKey: activeKey)
                try diskStorage.delete(forKey: pendingKey)

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
                continue
            }
        }
    }

    // MARK: - Stalled request operations

    func checkStalledUploadsOperation(tasks: [URLSessionTask]) {
        guard let currentEndpoint = endpoint else {
            return
        }

        let allTaskDescriptions = tasks
            .compactMap(\.taskDescription)
            .compactMap { try? JSONDecoder().decode(RequestDescriptor.self, from: Data($0.utf8)) }

        let cancelTime = Date(timeIntervalSinceNow: -1 * config.timeout)

        // Cancel stalled tasks and tasks with mismatched endpoints
        let toCancelTasks = tasks.filter { task in
            guard let expectedExecutionDate = task.earliestBeginDate else {
                return true
            }

            if expectedExecutionDate < cancelTime {
                return true
            }

            if let taskDescription = task.taskDescription,
                let descriptor = try? JSONDecoder().decode(RequestDescriptor.self, from: Data(taskDescription.utf8)),
                descriptor.endpoint != currentEndpoint
            {
                return true
            }
            return false
        }

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

        guard let uploadList = (try? diskStorage.list(forKey: getStorageKey()))?.map(\.key) else {
            return
        }

        checkAndSend(fileKeys: uploadList, existingTasks: allTaskDescriptions, cancelledTaskIds: cancelledTaskIds)
    }

    func checkAndSend(
        fileKeys files: [String],
        existingTasks allTaskDescriptions: [RequestDescriptorProtocol],
        cancelledTaskIds: Set<UUID>
    ) {
        let (currentEndpoint, currentHeaders) = getEndpointState()
        guard let currentEndpoint else {
            return
        }

        for fileKey in files {
            guard let requestId = UUID(uuidString: fileKey) else {
                continue
            }

            if let existingTaskDescription = allTaskDescriptions.first(where: { $0.id == requestId }) {
                if cancelledTaskIds.contains(requestId) {
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
            else {
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

    private func getEndpointState() -> (endpoint: URL?, headers: [String: String]) {
        stateLock.lock()
        defer { stateLock.unlock() }
        return (storedEndpoint, storedAdditionalHeaders)
    }

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
