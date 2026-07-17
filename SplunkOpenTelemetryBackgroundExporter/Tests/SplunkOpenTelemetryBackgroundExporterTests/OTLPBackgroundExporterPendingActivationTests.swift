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
import Testing

@testable import SplunkOpenTelemetryBackgroundExporter

@Suite
struct PendingEndpointActivationTests {
    @Test
    func endpointSetDuringPendingWriteSchedulesAnotherActivation() throws {
        let backingDisk = FilesystemDiskStorage(
            prefix: FilesystemPrefix(module: "OTLPBackgroundExporterPendingActivationTests.\(UUID().uuidString)"),
            rules: Rules(),
            encryption: NoneEncryption()
        )
        let disk = PreInsertBlockingDiskStorage(wrapping: backingDisk)
        let exporter = OTLPBackgroundHTTPBaseExporter(
            endpoint: nil,
            qosConfig: SessionQOSConfiguration(),
            envVarHeaders: nil,
            diskStorage: disk,
            performStalledUploadCheck: false
        )
        let httpClient = PendingActivationSendSpyHTTPClient()
        exporter.httpClient = httpClient

        let requestID = UUID()
        let pendingKey = exporter.getPendingStorageKey().append(requestID.uuidString)
        let activeKey = exporter.getStorageKey().append(requestID.uuidString)
        let pendingWriteReturned = DispatchSemaphore(value: 0)
        disk.observeDelete(for: pendingKey)
        defer {
            disk.resumeInsert()
            try? disk.delete(forKey: pendingKey)
            try? disk.delete(forKey: activeKey)
        }

        DispatchQueue.global(qos: .utility)
            .async {
                try? exporter.storePendingData(Data("payload".utf8), requestId: requestID)
                pendingWriteReturned.signal()
            }

        #expect(disk.waitUntilInsertStarts(timeout: 5) == .success)

        let endpoint = try #require(URL(string: "https://example.com/v1/traces"))
        exporter.setEndpoint(endpoint)
        #expect(disk.waitUntilListReturns(timeout: 5) == .success)

        disk.resumeInsert()

        #expect(pendingWriteReturned.wait(timeout: .now() + 5) == .success)
        #expect(httpClient.waitForSend(timeout: 5) == .success)
        #expect(disk.waitUntilObservedDelete(timeout: 5) == .success)
        #expect(httpClient.sentEndpoints == [endpoint])
        #expect(try disk.list(forKey: exporter.getPendingStorageKey()).isEmpty)
    }
}

private final class PreInsertBlockingDiskStorage: DiskStorage {
    private let wrapped: any DiskStorage
    private let insertStarted = DispatchSemaphore(value: 0)
    private let resumeInsertSemaphore = DispatchSemaphore(value: 0)
    private let listReturned = DispatchSemaphore(value: 0)
    private let observedDelete = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var shouldBlockInsert = true
    private var observedDeleteKey: String?

    init(wrapping wrapped: any DiskStorage) {
        self.wrapped = wrapped
    }

    var statistics: (any Statistics)? {
        wrapped.statistics
    }

    func insert(_ value: some Decodable & Encodable, forKey key: KeyBuilder) throws {
        lock.lock()
        let shouldBlock = shouldBlockInsert
        shouldBlockInsert = false
        lock.unlock()

        if shouldBlock {
            insertStarted.signal()
            resumeInsertSemaphore.wait()
        }

        try wrapped.insert(value, forKey: key)
    }

    func read<T: Decodable & Encodable>(forKey key: KeyBuilder) throws -> T? {
        try wrapped.read(forKey: key)
    }

    func update(_ value: some Decodable & Encodable, forKey key: KeyBuilder) throws {
        try wrapped.update(value, forKey: key)
    }

    func delete(forKey key: KeyBuilder) throws {
        try wrapped.delete(forKey: key)

        lock.lock()
        let shouldSignal = observedDeleteKey == key.key
        lock.unlock()

        if shouldSignal {
            observedDelete.signal()
        }
    }

    func list(forKey key: KeyBuilder) throws -> [ItemInfo] {
        defer { listReturned.signal() }
        return try wrapped.list(forKey: key)
    }

    func finalDestination(forKey key: KeyBuilder) throws -> URL {
        try wrapped.finalDestination(forKey: key)
    }

    func checkRules() throws {
        try wrapped.checkRules()
    }

    func waitUntilInsertStarts(timeout: TimeInterval) -> DispatchTimeoutResult {
        insertStarted.wait(timeout: .now() + timeout)
    }

    func waitUntilListReturns(timeout: TimeInterval) -> DispatchTimeoutResult {
        listReturned.wait(timeout: .now() + timeout)
    }

    func observeDelete(for key: KeyBuilder) {
        lock.lock()
        observedDeleteKey = key.key
        lock.unlock()
    }

    func waitUntilObservedDelete(timeout: TimeInterval) -> DispatchTimeoutResult {
        observedDelete.wait(timeout: .now() + timeout)
    }

    func resumeInsert() {
        resumeInsertSemaphore.signal()
    }
}

private final class PendingActivationSendSpyHTTPClient: NSObject, BackgroundHTTPClientProtocol {
    private let lock = NSLock()
    private let sendCalled = DispatchSemaphore(value: 0)
    private var storedSentEndpoints: [URL] = []

    var sentEndpoints: [URL] {
        lock.lock()
        defer { lock.unlock() }
        return storedSentEndpoints
    }

    func send(_ requestDescriptor: RequestDescriptorProtocol) {
        lock.lock()
        storedSentEndpoints.append(requestDescriptor.endpoint)
        lock.unlock()
        sendCalled.signal()
    }

    func flush(completion: @escaping () -> Void) {
        completion()
    }

    func getAllSessionsTasks(_ completionHandler: @escaping ([URLSessionTask]) -> Void) {
        completionHandler([])
    }

    func waitForSend(timeout: TimeInterval) -> DispatchTimeoutResult {
        sendCalled.wait(timeout: .now() + timeout)
    }
}
