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
import SplunkCommon

/// Basic implementation of exporters.
public class OTLPBackgroundHTTPBaseExporter {

    // MARK: - Private

    private let qosConfig: SessionQOSConfiguration
    private let performStalledUploadCheck: Bool
    private let endpointMaintenanceQueue = DispatchQueue(
        label: PackageIdentifier.default(named: "EndpointMaintenance"),
        qos: .utility
    )
    private let stateLock = NSLock()
    private var storedEndpoint: URL?
    private var storedAdditionalHeaders: [String: String]
    private var endpointRevision: UInt64 = 0

    // MARK: - Internal

    let fileType: String?
    let envVarHeaders: [(String, String)]?
    let config: OTLPExporterConfiguration
    let diskStorage: DiskStorage

    /// State used by the recovery extension.
    ///
    /// Access is serialized by `stalledUploadCheckLock`.
    let stalledUploadCheckLock = NSLock()
    var stalledUploadCheckGeneration: UInt64 = 0
    var checkStalledTask: Task<Void, Never>?

    /// Delay before scanning active storage for persisted files without a matching upload task.
    ///
    /// Overridable by tests so recovery behavior can be exercised without a production-length wait.
    var stalledUploadCheckDelayNanoseconds: UInt64 {
        UInt64(Int.random(in: 5 ... 8) * 1_000_000_000)
    }

    /// Thread-safe accessor for the endpoint URL.
    var endpoint: URL? {
        stateLock.lock()
        defer { stateLock.unlock() }
        return storedEndpoint
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
        cancelStalledUploadCheck()
    }

    // MARK: - Endpoint Management

    /// Updates the endpoint and asynchronously activates any pending data.
    ///
    /// In-flight uploads targeting the previous endpoint are rescheduled by the stalled upload check (within 5–8s).
    public func setEndpoint(_ newEndpoint: URL, headers newHeaders: [String: String]? = nil) {
        stateLock.lock()
        endpointRevision &+= 1
        let activationRevision = endpointRevision
        storedEndpoint = newEndpoint
        if let newHeaders {
            storedAdditionalHeaders = newHeaders
        }
        stateLock.unlock()

        endpointMaintenanceQueue.async {
            self.flushPendingData(for: activationRevision)
        }

        if performStalledUploadCheck {
            startStalledUploadCheck(replacingExisting: true)
        }
    }

    /// Clears the endpoint, causing new data to be cached to pending storage.
    public func clearEndpoint() {
        cancelStalledUploadCheck()

        stateLock.lock()
        endpointRevision &+= 1
        storedEndpoint = nil
        stateLock.unlock()
    }


    // MARK: - Flush

    /// Requests that `URLSession` flush its pending state without allowing the caller to wait forever.
    ///
    /// The exporter configuration is the hard upper bound. An explicit timeout may shorten that
    /// window, but cannot extend it.
    func flushHTTPClient(explicitTimeout: TimeInterval? = nil) -> Bool {
        let configuredTimeout =
            config.timeout.isFinite
            ? max(0, config.timeout)
            : OTLPExporterConfiguration.defaultTimeoutInterval
        let requestedTimeout =
            explicitTimeout.flatMap { timeout in
                timeout.isFinite ? max(0, timeout) : nil
            } ?? configuredTimeout
        let timeout = min(requestedTimeout, configuredTimeout)
        let completed = DispatchSemaphore(value: 0)

        httpClient.flush {
            completed.signal()
        }

        return completed.wait(timeout: .now() + timeout) == .success
    }

    // MARK: - Stalled request operations

    func checkStalledUploadsOperation(tasks: [URLSessionTask]) {
        guard let currentEndpoint = endpoint else {
            return
        }

        let allTaskDescriptions =
            tasks
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

            if allTaskDescriptions.first(where: { $0.id == requestId }) != nil {
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
                // This task was forgotten by system, create new one.
                let payloadFormat = inferPayloadFormat(forFileKey: fileKey)
                let taskDescription = RequestDescriptor(
                    id: requestId,
                    endpoint: currentEndpoint,
                    explicitTimeout: config.timeout,
                    fileKeyType: getFileKeyType(),
                    headers: buildHeaders(from: currentHeaders),
                    payloadFormat: payloadFormat
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

    var headers: [String: String] {
        buildHeaders(from: additionalHeaders)
    }

    /// Schedules another pending-storage scan when an endpoint became active during a pending write.
    func activatePendingDataIfEndpointAvailable() {
        stateLock.lock()
        let activationRevision = storedEndpoint == nil ? nil : endpointRevision
        stateLock.unlock()

        guard let activationRevision else {
            return
        }

        endpointMaintenanceQueue.async {
            self.flushPendingData(for: activationRevision)
        }
    }
}

// MARK: - Private helpers

extension OTLPBackgroundHTTPBaseExporter {
    /// Flushes any data stored in pending storage by moving it to active storage and scheduling uploads.
    private func flushPendingData(for activationRevision: UInt64) {
        guard endpointState(for: activationRevision) != nil else {
            return
        }

        guard let pendingFiles = try? diskStorage.list(forKey: getPendingStorageKey()) else {
            return
        }

        for fileInfo in pendingFiles {
            guard endpointState(for: activationRevision) != nil else {
                return
            }

            guard let requestId = UUID(uuidString: fileInfo.key) else {
                continue
            }

            let pendingKey = KeyBuilder(fileInfo.key, parrentKeyBuilder: getPendingStorageKey())
            let activeKey = KeyBuilder(fileInfo.key, parrentKeyBuilder: getStorageKey())

            do {
                let pendingFileUrl = try diskStorage.finalDestination(forKey: pendingKey)
                let data = try Data(contentsOf: pendingFileUrl)
                try diskStorage.insert(data, forKey: activeKey)

                guard let (currentEndpoint, currentHeaders) = endpointState(for: activationRevision) else {
                    return
                }

                let requestDescriptor = RequestDescriptor(
                    id: requestId,
                    endpoint: currentEndpoint,
                    explicitTimeout: config.timeout,
                    fileKeyType: getFileKeyType(),
                    headers: buildHeaders(from: currentHeaders)
                )
                try httpClient.send(requestDescriptor)
                try diskStorage.delete(forKey: pendingKey)
            }
            catch {
                continue
            }
        }
    }

    private func getEndpointState() -> (endpoint: URL?, headers: [String: String]) {
        stateLock.lock()
        defer { stateLock.unlock() }
        return (storedEndpoint, storedAdditionalHeaders)
    }

    private func endpointState(for activationRevision: UInt64) -> (endpoint: URL, headers: [String: String])? {
        stateLock.lock()
        defer { stateLock.unlock() }

        guard endpointRevision == activationRevision, let storedEndpoint else {
            return nil
        }

        return (storedEndpoint, storedAdditionalHeaders)
    }
}
