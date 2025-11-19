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
import CiscoEncryption
import Foundation
import OpenTelemetryProtocolExporterCommon
import SplunkCommon
import Testing
import XCTest

@testable import SplunkOpenTelemetryBackgroundExporter

@Suite
struct SplunkBackgroundHTTPBaseExporterTests {

    // MARK: - Helpers

    func makeExporter(
        disk: MockDiskStorage,
        http: MockHTTPClient,
        config: OtlpConfiguration = OtlpConfiguration()
    ) throws -> OTLPBackgroundHTTPBaseExporter {
        let exporter = try OTLPBackgroundHTTPBaseExporter(
            endpoint: XCTUnwrap(URL(string: "https://example.com")),
            config: config,
            qosConfig: SessionQOSConfiguration(),
            envVarHeaders: nil,
            diskStorage: disk,
            performStalledUploadCheck: false
        )
        exporter.httpClient = http
        return exporter
    }

    func createNewTestTask() throws -> URLSessionDataTask {
        try URLSession(configuration: .default).dataTask(with: MockRequestDescriptor().createRequest())
    }


    // MARK: - Tests

    @Test
    func diskStorageThrows() throws {
        let disk = MockDiskStorage()
        disk.shouldThrowOnlist = true
        let http = MockHTTPClient()
        let exporter = try makeExporter(disk: disk, http: http)

        let task = try createNewTestTask()
        task.earliestBeginDate = Date()

        exporter.checkStalledUploadsOperation(tasks: [task])

        #expect(task.state != .canceling)
        #expect(http.sent.isEmpty)
    }

    @Test
    func diskStorageWorks() throws {
        let desc = try MockRequestDescriptor()

        let disk = FilesystemDiskStorage(
            prefix: FilesystemPrefix(module: "SplunkOTLPBackgroundHTTPBaseExporterTests.testDiskStorageWorks"),
            rules: Rules(
                relativeUsedSize: 0.2,
                absoluteUsedSize: .init(value: 200, unit: .megabytes)
            ),
            encryption: NoneEncryption()
        )

        let exporter = try MockOTLPBackgroundHTTPBaseExporter(
            endpoint: XCTUnwrap(URL(string: "https://example.com")),
            config: OtlpConfiguration(),
            qosConfig: SessionQOSConfiguration(),
            envVarHeaders: nil,
            diskStorage: disk,
            performStalledUploadCheck: false
        )

        try disk.insert(desc, forKey: exporter.getStorageKey().append(desc.id.uuidString))

        exporter.checkStalledUploadsOperation(tasks: [])

        #expect(exporter.checkAndSendCalledWithFiles.first == desc.id.uuidString)
    }

    @Test
    func taskWithNilEarliestBeginDateIsCancelled() throws {
        let disk = MockDiskStorage()
        let http = MockHTTPClient()
        let exporter = try makeExporter(disk: disk, http: http)

        let task = try createNewTestTask()
        task.earliestBeginDate = nil

        exporter.checkStalledUploadsOperation(tasks: [task])

        #expect(task.state == .canceling)
    }

    @Test
    func onlyStalledTasksAreCancelled() throws {
        let disk = MockDiskStorage()
        let http = MockHTTPClient()
        let exporter = try makeExporter(disk: disk, http: http, config: OtlpConfiguration(timeout: 1))

        let now = Date()
        let old = now.addingTimeInterval(-1_000)
        let fresh = now

        let tOld = try createNewTestTask()
        tOld.taskDescription = try MockRequestDescriptor(scheduled: old).json
        tOld.earliestBeginDate = old

        let tfresh = try createNewTestTask()
        tfresh.taskDescription = try MockRequestDescriptor(scheduled: old).json
        tfresh.earliestBeginDate = fresh

        exporter.checkStalledUploadsOperation(tasks: [tOld, tfresh])

        #expect(tOld.state != .running)
        #expect(tfresh.state != .canceling)
    }

    @Test
    func fileWithInvalidUUIDIsSkipped() throws {
        let disk = MockDiskStorage()
        let http = MockHTTPClient()

        let exporter = try makeExporter(disk: disk, http: http)
        exporter.checkAndSend(fileKeys: ["non-working-uuid"], existingTasks: [], cancelTime: Date())

        #expect(http.sent.isEmpty)
    }

    @Test
    func fileWithNonStalledTaskIsNotResent() throws {
        let uuid = UUID()
        let disk = MockDiskStorage()
        let desc = try MockRequestDescriptor(id: uuid, scheduled: Date().addingTimeInterval(1_000))

        let http = MockHTTPClient()
        let exporter = try makeExporter(disk: disk, http: http)

        exporter.checkAndSend(fileKeys: [uuid.uuidString], existingTasks: [desc], cancelTime: Date())

        #expect(http.sent.isEmpty)
    }

    @Test
    func fileWithStalledTaskIsResent() throws {
        let uuid = UUID()
        let disk = MockDiskStorage()
        let desc = try MockRequestDescriptor(
            id: uuid,
            explicitTimeout: 1,
            sentCount: 5,
            fileKeyType: "base",
            scheduled: Date(timeIntervalSinceNow: -1_000)
        )

        let http = MockHTTPClient()
        let exporter = try makeExporter(disk: disk, http: http)

        exporter.checkAndSend(fileKeys: [uuid.uuidString], existingTasks: [desc], cancelTime: Date())

        #expect(http.sent.count == 1)
        #expect(http.sent.first?.id == uuid)
    }

    @Test
    func fileWithNoTaskDescriptionIsSentAsNew() throws {
        let uuid = UUID()
        let disk = MockDiskStorage()
        let http = MockHTTPClient()

        let exporter = try makeExporter(disk: disk, http: http)

        exporter.checkAndSend(fileKeys: [uuid.uuidString], existingTasks: [], cancelTime: Date())

        #expect(http.sent.count == 1)
        #expect(http.sent.first?.id == uuid)
    }

    @Test
    func exporterWasCreatedAndCheckStalledWasCalled() async throws {
        let exporter = try MockOTLPBackgroundHTTPBaseExporter(
            endpoint: XCTUnwrap(URL(string: "https://example.com")),
            config: OtlpConfiguration(),
            qosConfig: SessionQOSConfiguration(),
            envVarHeaders: nil,
            diskStorage: MockDiskStorage()
        )

        try await Task.sleep(nanoseconds: 10_000_000_000) // wait for 10 secs

        #expect(exporter.checkStalledUploadsOperationCalled == true)
    }
}
