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

import CiscoEncryption
import Foundation
import SplunkCommon
import Testing

@testable import SplunkOpenTelemetryBackgroundExporter

final class MockHTTPClient: NSObject, BackgroundHTTPClientProtocol {

    var sent: [RequestDescriptorProtocol] = []

    func flush(completion _: @escaping () -> Void) {}

    func getAllSessionsTasks(_: @escaping ([URLSessionTask]) -> Void) {}

    func send(_ requestDescriptor: RequestDescriptorProtocol) throws {
        sent.append(requestDescriptor)
    }
}

final class ThrowingHTTPClient: NSObject, BackgroundHTTPClientProtocol {
    enum StubError: Error {
        case sendFailed
    }

    func send(_ requestDescriptor: RequestDescriptorProtocol) throws {
        _ = requestDescriptor
        throw StubError.sendFailed
    }

    func flush(completion: @escaping () -> Void) {
        completion()
    }

    func getAllSessionsTasks(_ completionHandler: @escaping ([URLSessionTask]) -> Void) {
        completionHandler([])
    }
}

final class FirstSendThrowingHTTPClient: NSObject, BackgroundHTTPClientProtocol {
    enum StubError: Error {
        case firstSendFailed
    }

    private let lock = NSLock()
    private let recoveredSend = DispatchSemaphore(value: 0)
    private var storedSendAttemptCount = 0
    private var storedSuccessfulRequests: [RequestDescriptorProtocol] = []

    var sendAttemptCount: Int {
        withLock { storedSendAttemptCount }
    }

    var successfulRequests: [RequestDescriptorProtocol] {
        withLock { storedSuccessfulRequests }
    }

    func send(_ requestDescriptor: RequestDescriptorProtocol) throws {
        let shouldFail = withLock {
            storedSendAttemptCount += 1
            return storedSendAttemptCount == 1
        }

        guard !shouldFail else {
            throw StubError.firstSendFailed
        }

        withLock {
            storedSuccessfulRequests.append(requestDescriptor)
        }
        recoveredSend.signal()
    }

    func flush(completion: @escaping () -> Void) {
        completion()
    }

    func getAllSessionsTasks(_ completionHandler: @escaping ([URLSessionTask]) -> Void) {
        completionHandler([])
    }

    func waitForRecoveredSend(timeout: TimeInterval) -> DispatchTimeoutResult {
        recoveredSend.wait(timeout: .now() + timeout)
    }

    private func withLock<T>(_ work: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try work()
    }
}

final class AlwaysThrowingHTTPClient: NSObject, BackgroundHTTPClientProtocol {
    enum StubError: Error {
        case sendFailed
    }

    private let lock = NSLock()
    private let recoveryScan = DispatchSemaphore(value: 0)
    private var storedRecoveryScanCount = 0
    private var storedSendAttemptCount = 0

    var recoveryScanCount: Int {
        withLock { storedRecoveryScanCount }
    }

    var sendAttemptCount: Int {
        withLock { storedSendAttemptCount }
    }

    func send(_: RequestDescriptorProtocol) throws {
        withLock {
            storedSendAttemptCount += 1
        }
        throw StubError.sendFailed
    }

    func flush(completion: @escaping () -> Void) {
        completion()
    }

    func getAllSessionsTasks(_ completionHandler: @escaping ([URLSessionTask]) -> Void) {
        withLock {
            storedRecoveryScanCount += 1
        }
        completionHandler([])
        recoveryScan.signal()
    }

    func waitForRecoveryScan(timeout: TimeInterval) -> DispatchTimeoutResult {
        recoveryScan.wait(timeout: .now() + timeout)
    }

    private func withLock<T>(_ work: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try work()
    }
}

final class FlushSpyHTTPClient: NSObject, BackgroundHTTPClientProtocol {
    var sent: [RequestDescriptorProtocol] = []
    var flushed = false

    func send(_ requestDescriptor: RequestDescriptorProtocol) throws {
        sent.append(requestDescriptor)
    }

    func flush(completion: @escaping () -> Void) {
        flushed = true
        completion()
    }

    func getAllSessionsTasks(_ completionHandler: @escaping ([URLSessionTask]) -> Void) {
        completionHandler([])
    }
}
