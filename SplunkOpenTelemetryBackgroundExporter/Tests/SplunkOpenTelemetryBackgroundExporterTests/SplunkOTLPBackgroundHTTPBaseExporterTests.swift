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
import OpenTelemetryProtocolExporterCommon
import CiscoEncryption

@testable import SplunkOpenTelemetryBackgroundExporter

@Suite
struct SplunkOTLPBackgroundHTTPBaseExporterTests {

    func makeExporter(
        disk: FakeDiskStorage,
        http: FakeHTTPClient,
        config: OtlpConfiguration = OtlpConfiguration(),
        endpoint: URL = URL(string: "https://example.com")!
    ) -> OTLPBackgroundHTTPBaseExporter {
        let exporter = OTLPBackgroundHTTPBaseExporter(
            endpoint: endpoint,
            config: config,
            qosConfig: SessionQOSConfiguration(),
            envVarHeaders: nil,
            diskStorage: disk
        )
        exporter.httpClient = http
        return exporter
    }

    @Test
    func testDiskStorageThrows() {
        let disk = FakeDiskStorage()
        disk.shouldThrowOnlist = true
        let http = FakeHTTPClient()
        let exporter = makeExporter(disk: disk, http: http)

        let task = URLSessionTask.createNewTestTask()
        task.earliestBeginDate = .now

        exporter.checkStalledUploadsOperation(tasks: [task])

        #expect(task.state != .canceling)
        #expect(http.sent.isEmpty)
    }

    @Test
    func testDiskStorageWorks() throws {
        let desc = FakeRequestDescriptor()

        let disk = FilesystemDiskStorage(
            prefix: FilesystemPrefix(module: "SplunkOTLPBackgroundHTTPBaseExporterTests.testDiskStorageWorks"),
            rules: Rules(
                relativeUsedSize: 0.2,
                absoluteUsedSize: .init(value: 200, unit: .megabytes)
            ),
            encryption: NoneEncryption()
        )

        let exporter = FakeOTLPBackgroundHTTPBaseExporter(
            endpoint: URL(string: "https://example.com")!,
            config: OtlpConfiguration(),
            qosConfig: SessionQOSConfiguration(),
            envVarHeaders: nil,
            diskStorage: disk
        )

        try disk.insert(desc, forKey: exporter.getStorageKey().append(desc.id.uuidString))

        exporter.checkStalledUploadsOperation(tasks: [])

        #expect(exporter.checkAndSendCalledWithFiles.first == desc.id.uuidString)
    }

    @Test
    func testTaskWithNilEarliestBeginDateIsCancelled() {
        let disk = FakeDiskStorage()
        let http = FakeHTTPClient()
        let exporter = makeExporter(disk: disk, http: http)

        let task = URLSessionTask.createNewTestTask()
        task.earliestBeginDate = nil

        exporter.checkStalledUploadsOperation(tasks: [task])

        #expect(task.state == .canceling)
    }

    @Test
    func testOnlyStalledTasksAreCancelled() {
        let disk = FakeDiskStorage()
        let http = FakeHTTPClient()
        let exporter = makeExporter(disk: disk, http: http, config: OtlpConfiguration(timeout: 1))

        let now = Date()
        let old = now.addingTimeInterval(-1000)
        let fresh = now

        let tOld = URLSessionTask.createNewTestTask()
        tOld.taskDescription = FakeRequestDescriptor(scheduled: old).json
        tOld.earliestBeginDate = old

        let tfresh = URLSessionTask.createNewTestTask()
        tfresh.taskDescription = FakeRequestDescriptor(scheduled: old).json
        tfresh.earliestBeginDate = fresh

        exporter.checkStalledUploadsOperation(tasks: [tOld, tfresh])

        #expect(tOld.state != .running)
        #expect(tfresh.state != .canceling)
    }

    @Test
    func testFileWithInvalidUUIDIsSkipped() {
        let disk = FakeDiskStorage()
        let http = FakeHTTPClient()

        let exporter = makeExporter(disk: disk, http: http)
        exporter.checkAndSend(fileKeys: ["non-working-uuid"], existingTasks: [], cancelTime: .now)

        #expect(http.sent.isEmpty)
    }

    @Test
    func testFileWithNonStalledTaskIsNotResent() {
        let uuid = UUID()
        let disk = FakeDiskStorage()
        let desc = FakeRequestDescriptor(id: uuid, scheduled: .now.addingTimeInterval(1000))

        let http = FakeHTTPClient()
        let exporter = makeExporter(disk: disk, http: http)

        exporter.checkAndSend(fileKeys: [uuid.uuidString], existingTasks: [desc], cancelTime: .now)

        #expect(http.sent.isEmpty)
    }

    @Test
    func testFileWithStalledTaskIsResent() {
        let uuid = UUID()
        let disk = FakeDiskStorage()
        let desc = FakeRequestDescriptor(id: uuid, endpoint: URL(string: "example.com")!, explicitTimeout: 1, sentCount: 5, fileKeyType: "base", scheduled: .now.addingTimeInterval(-1000))

        let http = FakeHTTPClient()
        let exporter = makeExporter(disk: disk, http: http)

        exporter.checkAndSend(fileKeys: [uuid.uuidString], existingTasks: [desc], cancelTime: .now)

        #expect(http.sent.count == 1)
        #expect(http.sent.first?.id == uuid)
    }

    @Test
    func testFileWithNoTaskDescriptionIsSentAsNew() {
        let uuid = UUID()
        let disk = FakeDiskStorage()
        let http = FakeHTTPClient()

        let exporter = makeExporter(disk: disk, http: http)

        exporter.checkAndSend(fileKeys: [uuid.uuidString], existingTasks: [], cancelTime: .now)

        #expect(http.sent.count == 1)
        #expect(http.sent.first?.id == uuid)
    }

    @Test
    func testExporterWasCreatedAndCheckStalledWasCalled() async throws {
        let exporter = FakeOTLPBackgroundHTTPBaseExporter(
            endpoint: URL(string: "https://example.com")!,
            config: OtlpConfiguration(),
            qosConfig: SessionQOSConfiguration(),
            envVarHeaders: nil,
            diskStorage: FakeDiskStorage()
        )

        try await Task.sleep(nanoseconds: 10_000_000_000) // wait for 10 secs

        #expect(exporter.checkStalledUploadsOperationCalled == true)
    }
}
