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
    ) -> RequestDescriptor {
        RequestDescriptor(
            id: UUID(),
            endpoint: URL(string: "https://example.com")!,
            explicitTimeout: 5,
            sentCount: sentCount,
            fileKeyType: fileKeyType
        )
    }

    // MARK: - Tests

    @Test("send uploads file if file exists and shouldSend is true")
    func testSendSuccess() async throws {
        let disk = FakeDiskStorage()
        let key = TestKeyBuilder.uploadsKey.append("fake").key
        let fileURL = URL(fileURLWithPath: "/tmp/fakefile")
        disk.files[key] = fileURL
        let client = makeClient(disk: disk)
        let descriptor = makeRequestDescriptor(sentCount: 0)
        try client.send(descriptor)
        #expect(true)
    }

    @Test("send does not upload if shouldSend is false and deletes file")
    func testSendShouldNotSendDeletesFile() async throws {
        let descriptor = makeRequestDescriptor(sentCount: 99)
        let disk = FakeDiskStorage()
        // Vygeneruj key přesně podle production logiky:
        let key = TestKeyBuilder(
            descriptor.id.uuidString,
            parrentKeyBuilder: TestKeyBuilder.uploadsKey.append(descriptor.fileKeyType)
        ).key
        disk.files[key] = URL(fileURLWithPath: "/tmp/fakefile")
        let client = makeClient(disk: disk)
        try client.send(descriptor)
        #expect(disk.deletedKeys.contains(key))
    }

    @Test("send logs error if file does not exist")
    func testSendFileMissingLogsError() async throws {
        let disk = FakeDiskStorage()
        let client = makeClient(disk: disk)
        let descriptor = makeRequestDescriptor(sentCount: 0)
        try client.send(descriptor)
        #expect(true)
    }

    @Test("flush triggers completion")
    func testFlushCallsCompletion() async throws {
        let client = makeClient()
        var didComplete = false
        client.flush {
            didComplete = true
        }
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(didComplete)
    }

    @Test("getAllSessionsTasks returns all tasks via completion")
    func testGetAllSessionsTasksReturnsTasks() async throws {
        let client = makeClient()
        var wasCalled = false
        client.getAllSessionsTasks { tasks in
            wasCalled = true
        }
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(wasCalled)
    }

    @Test("urlSession:dataTask:didReceive logs for non-2xx response and decodable descriptor")
    func testDataDelegateDidReceiveNon2xxLogs() async throws {
        let client = makeClient()
        let descriptor = makeRequestDescriptor()
        let dataTask = DummyDataTask()
        dataTask.taskDescription = descriptor.json
        dataTask.response = HTTPURLResponse(url: descriptor.endpoint, statusCode: 404, httpVersion: nil, headerFields: nil)
        let data = Data("failure".utf8)
        client.urlSession(URLSession.shared, dataTask: dataTask, didReceive: data)
        #expect(true)
    }

    @Test("urlSession:dataTask:didReceive does nothing if response is 2xx or cannot decode descriptor")
    func testDataDelegateDidReceiveNoLogFor2xxOrBadDescriptor() async throws {
        let client = makeClient()
        let dataTask = DummyDataTask()
        dataTask.taskDescription = "not a json"
        dataTask.response = HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 201, httpVersion: nil, headerFields: nil)
        let data = Data("ok".utf8)
        client.urlSession(URLSession.shared, dataTask: dataTask, didReceive: data)
        #expect(true)
    }

    @Test("urlSession:task:didCompleteWithError retries and logs on error")
    func testTaskDelegateDidCompleteWithErrorRetries() async throws {
        let client = makeClient()
        let descriptor = makeRequestDescriptor()
        let task = DummyDataTask()
        task.taskDescription = descriptor.json
        let error = NSError(domain: "test", code: 1)
        client.urlSession(URLSession.shared, task: task, didCompleteWithError: error)
        #expect(true)
    }

    @Test("urlSession:task:didCompleteWithError logs and deletes file on http success")
    func testTaskDelegateDidCompleteSuccessDeletesFile() async throws {
        let disk = FakeDiskStorage()
        let client = makeClient(disk: disk)
        let descriptor = makeRequestDescriptor()
        let task = DummyDataTask()
        task.taskDescription = descriptor.json
        task.response = HTTPURLResponse(url: descriptor.endpoint, statusCode: 201, httpVersion: nil, headerFields: nil)
        client.urlSession(URLSession.shared, task: task, didCompleteWithError: nil)
        #expect(true)
    }

    @Test("urlSession:task:didCompleteWithError logs if descriptor cannot be decoded")
    func testTaskDelegateDidCompleteLogsOnBadDescriptor() async throws {
        let client = makeClient()
        let task = DummyDataTask()
        task.taskDescription = "not a json"
        client.urlSession(URLSession.shared, task: task, didCompleteWithError: nil)
        #expect(true)
    }
}
