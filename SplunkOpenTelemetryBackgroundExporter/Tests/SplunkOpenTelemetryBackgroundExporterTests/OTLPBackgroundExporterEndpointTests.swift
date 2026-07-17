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

@Suite(.serialized)
struct OTLPBackgroundExporterEndpointTests {

    @Test
    func settingEndpointDoesNotWaitForPendingDiskScan() throws {
        let disk = MockDiskStorage()
        let scanStarted = DispatchSemaphore(value: 0)
        let resumeScan = DispatchSemaphore(value: 0)
        let callReturned = DispatchSemaphore(value: 0)
        disk.onList = {
            scanStarted.signal()
            resumeScan.wait()
        }
        defer { resumeScan.signal() }

        let exporter = OTLPBackgroundHTTPBaseExporter(
            endpoint: nil,
            qosConfig: SessionQOSConfiguration(),
            envVarHeaders: nil,
            diskStorage: disk,
            performStalledUploadCheck: false
        )
        let endpoint = try #require(URL(string: "https://example.com/v1/traces"))

        DispatchQueue.global()
            .async {
                exporter.setEndpoint(endpoint)
                callReturned.signal()
            }

        #expect(scanStarted.wait(timeout: .now() + 5) == .success)
        #expect(callReturned.wait(timeout: .now() + 5) == .success)
        #expect(exporter.endpoint == endpoint)
    }

    @Test
    func disablingEndpointCancelsInProgressPendingActivation() throws {
        let backingDisk = FilesystemDiskStorage(
            prefix: FilesystemPrefix(module: "OTLPBackgroundExporterEndpointTests.\(UUID().uuidString)"),
            rules: Rules(),
            encryption: NoneEncryption()
        )
        let disk = BlockingListDiskStorage(wrapping: backingDisk)
        let exporter = OTLPBackgroundHTTPBaseExporter(
            endpoint: nil,
            qosConfig: SessionQOSConfiguration(),
            envVarHeaders: nil,
            diskStorage: disk,
            performStalledUploadCheck: false
        )
        let httpClient = EndpointSendSpyHTTPClient()
        exporter.httpClient = httpClient

        let requestID = UUID().uuidString
        let pendingKey = exporter.getPendingStorageKey().append(requestID)
        let activeKey = exporter.getStorageKey().append(requestID)
        try disk.insert(Data("payload".utf8), forKey: pendingKey)
        defer {
            try? disk.delete(forKey: pendingKey)
            try? disk.delete(forKey: activeKey)
            disk.resumeList()
        }

        let endpoint = try #require(URL(string: "https://example.com/v1/traces"))
        exporter.setEndpoint(endpoint)
        #expect(disk.waitUntilListStarts(timeout: 5) == .success)

        exporter.clearEndpoint()
        disk.resumeList()

        #expect(disk.waitUntilListReturns(timeout: 5) == .success)
        #expect(httpClient.waitForSend(timeout: 0.2) == .timedOut)
        #expect(httpClient.sentEndpoints.isEmpty)
        #expect(exporter.endpoint == nil)
    }

    @Test
    func canceledActivationRetainsPendingPayloadForNextActivation() throws {
        let backingDisk = FilesystemDiskStorage(
            prefix: FilesystemPrefix(module: "OTLPBackgroundExporterEndpointTests.\(UUID().uuidString)"),
            rules: Rules(),
            encryption: NoneEncryption()
        )
        let disk = BlockingInsertDiskStorage(wrapping: backingDisk)
        let exporter = OTLPBackgroundHTTPBaseExporter(
            endpoint: nil,
            qosConfig: SessionQOSConfiguration(),
            envVarHeaders: nil,
            diskStorage: disk,
            performStalledUploadCheck: false
        )
        let httpClient = EndpointSendSpyHTTPClient()
        exporter.httpClient = httpClient

        let requestID = UUID().uuidString
        let pendingKey = exporter.getPendingStorageKey().append(requestID)
        let activeKey = exporter.getStorageKey().append(requestID)
        try disk.insert(Data("payload".utf8), forKey: pendingKey)
        disk.blockNextInsert(for: activeKey)
        disk.observeDelete(for: pendingKey)
        defer {
            disk.resumeInsert()
            try? disk.delete(forKey: pendingKey)
            try? disk.delete(forKey: activeKey)
        }

        let firstEndpoint = try #require(URL(string: "https://first.example.com/v1/traces"))
        let secondEndpoint = try #require(URL(string: "https://second.example.com/v1/traces"))
        exporter.setEndpoint(firstEndpoint)
        #expect(disk.waitUntilInsertStarts(timeout: 5) == .success)

        exporter.clearEndpoint()
        exporter.setEndpoint(secondEndpoint)
        disk.resumeInsert()

        #expect(httpClient.waitForSend(timeout: 5) == .success)
        #expect(disk.waitUntilObservedDelete(timeout: 5) == .success)
        #expect(httpClient.sentEndpoints == [secondEndpoint])
        #expect(try disk.list(forKey: exporter.getPendingStorageKey()).isEmpty)
    }
}

private final class BlockingListDiskStorage: DiskStorage {
    private let wrapped: any DiskStorage
    private let listStarted = DispatchSemaphore(value: 0)
    private let listReturned = DispatchSemaphore(value: 0)
    private let resumeListSemaphore = DispatchSemaphore(value: 0)

    init(wrapping wrapped: any DiskStorage) {
        self.wrapped = wrapped
    }

    var statistics: (any Statistics)? {
        wrapped.statistics
    }

    func insert(_ value: some Decodable & Encodable, forKey key: KeyBuilder) throws {
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
    }

    func list(forKey key: KeyBuilder) throws -> [ItemInfo] {
        listStarted.signal()
        resumeListSemaphore.wait()
        defer { listReturned.signal() }
        return try wrapped.list(forKey: key)
    }

    func finalDestination(forKey key: KeyBuilder) throws -> URL {
        try wrapped.finalDestination(forKey: key)
    }

    func checkRules() throws {
        try wrapped.checkRules()
    }

    func waitUntilListStarts(timeout: TimeInterval) -> DispatchTimeoutResult {
        listStarted.wait(timeout: .now() + timeout)
    }

    func waitUntilListReturns(timeout: TimeInterval) -> DispatchTimeoutResult {
        listReturned.wait(timeout: .now() + timeout)
    }

    func resumeList() {
        resumeListSemaphore.signal()
    }
}

private final class BlockingInsertDiskStorage: DiskStorage {
    private let wrapped: any DiskStorage
    private let insertStarted = DispatchSemaphore(value: 0)
    private let resumeInsertSemaphore = DispatchSemaphore(value: 0)
    private let observedDelete = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var blockedKey: String?
    private var observedDeleteKey: String?

    init(wrapping wrapped: any DiskStorage) {
        self.wrapped = wrapped
    }

    var statistics: (any Statistics)? {
        wrapped.statistics
    }

    func insert(_ value: some Decodable & Encodable, forKey key: KeyBuilder) throws {
        try wrapped.insert(value, forKey: key)

        lock.lock()
        let shouldBlock = blockedKey == key.key
        if shouldBlock {
            blockedKey = nil
        }
        lock.unlock()

        if shouldBlock {
            insertStarted.signal()
            resumeInsertSemaphore.wait()
        }
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
        try wrapped.list(forKey: key)
    }

    func finalDestination(forKey key: KeyBuilder) throws -> URL {
        try wrapped.finalDestination(forKey: key)
    }

    func checkRules() throws {
        try wrapped.checkRules()
    }

    func blockNextInsert(for key: KeyBuilder) {
        lock.lock()
        blockedKey = key.key
        lock.unlock()
    }

    func observeDelete(for key: KeyBuilder) {
        lock.lock()
        observedDeleteKey = key.key
        lock.unlock()
    }

    func waitUntilInsertStarts(timeout: TimeInterval) -> DispatchTimeoutResult {
        insertStarted.wait(timeout: .now() + timeout)
    }

    func waitUntilObservedDelete(timeout: TimeInterval) -> DispatchTimeoutResult {
        observedDelete.wait(timeout: .now() + timeout)
    }

    func resumeInsert() {
        resumeInsertSemaphore.signal()
    }
}

private final class EndpointSendSpyHTTPClient: NSObject, BackgroundHTTPClientProtocol {
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
