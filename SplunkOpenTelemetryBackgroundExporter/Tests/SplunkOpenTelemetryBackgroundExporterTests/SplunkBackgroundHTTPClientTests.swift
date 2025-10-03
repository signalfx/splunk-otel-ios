//
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
import Foundation
import SplunkCommon
import Testing

@testable import SplunkOpenTelemetryBackgroundExporter

@Suite
struct BackgroundHTTPClientTests {

    // MARK: - Helpers

    func createNewTestTask(with requestDescriptor: RequestDescriptor) -> URLSessionDataTask {
        URLSession(configuration: .default).dataTask(with: requestDescriptor.createRequest())
    }

    func makeClient(
        qos: SessionQOSConfiguration = SessionQOSConfiguration(),
        disk: FakeDiskStorage = FakeDiskStorage(),
        namespace: String = "test"
    ) -> BackgroundHTTPClient {
        BackgroundHTTPClient(
            sessionQosConfiguration: qos,
            diskStorage: disk,
            namespace: namespace
        )
    }

    func makeRequestDescriptor(
        sentCount: Int = 0,
        fileKeyType: String = "fake"
    ) throws -> RequestDescriptor {

        guard let url = URL(string: "https://example.com") else {
            throw URLError(.unknown)
        }

        return RequestDescriptor(
            id: UUID(),
            endpoint: url,
            explicitTimeout: 5,
            sentCount: sentCount,
            fileKeyType: fileKeyType
        )
    }

    // MARK: - Tests

    @Test
    func sendShouldNotSendDeletesFile() throws {
        let descriptor = try makeRequestDescriptor(sentCount: 99)
        let disk = FakeDiskStorage()
        let client = makeClient(disk: disk)

        let key = KeyBuilder(
            descriptor.id.uuidString,
            parrentKeyBuilder: KeyBuilder.uploadsKey.append(descriptor.fileKeyType)
        )
        .key
        disk.files[key] = URL(fileURLWithPath: "/tmp/fakefile")

        try client.send(descriptor)

        #expect(disk.deletedKeys.contains(key))
    }

    @Test
    func flushCallsCompletion() async throws {
        let client = makeClient()

        var didComplete = false
        client.flush {
            didComplete = true
        }

        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(didComplete)
    }

    @Test
    func getAllSessionsTasksReturnsTasks() async throws {
        var wasCalled = false

        let client = makeClient()
        client.getAllSessionsTasks { _ in
            wasCalled = true
        }

        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(wasCalled)
    }

    @Test
    func taskDelegateDidCompleteStatusCodeDeletesFile() throws {
        let disk = FakeDiskStorage()
        let client = makeClient(disk: disk)
        let descriptor = try makeRequestDescriptor()

        let response = HTTPURLResponse(url: descriptor.endpoint, statusCode: 201, httpVersion: nil, headerFields: nil)
        try client.taskCompleted(withResponse: response, requestDescriptor: descriptor, error: nil)

        let response404 = HTTPURLResponse(url: descriptor.endpoint, statusCode: 404, httpVersion: nil, headerFields: nil)
        try client.taskCompleted(withResponse: response404, requestDescriptor: descriptor, error: nil)

        #expect(disk.deletedKeys.isEmpty == false)
    }

    @Test
    func taskDelegateDidCompleteErrorNotDeletesFile() throws {
        let disk = FakeDiskStorage()
        let client = makeClient(disk: disk)
        let descriptor = try makeRequestDescriptor()

        let response = HTTPURLResponse(url: descriptor.endpoint, statusCode: 999, httpVersion: nil, headerFields: nil)
        try client.taskCompleted(withResponse: response, requestDescriptor: descriptor, error: CancellationError())

        #expect(disk.deletedKeys.isEmpty == true)
    }

    @Test
    func taskDelegateDidCompleteLogsOnBadDescriptor() throws {
        let client = makeClient()
        let descriptor = try makeRequestDescriptor()

        let task = createNewTestTask(with: descriptor)
        task.taskDescription = "not a json"

        client.urlSession(URLSession.shared, task: task, didCompleteWithError: nil)

        #expect(true)
    }
}
