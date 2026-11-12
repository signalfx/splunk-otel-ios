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

import Darwin
import Foundation
import Testing

@testable import SplunkOpenTelemetryBackgroundExporter

extension SplunkBackgroundHTTPBaseExporterTests {

    // MARK: - Fixtures

    private static var protobufPayloads: [Data] {
        let objectLengthPrefix: [UInt8] = [0x0A, 0x7B, 0x12, 0x79, 0x0A, 0x77, 0x0A, 0x75]
        let arrayLengthPrefix: [UInt8] = [0x0A, 0x5B, 0x12, 0x59, 0x0A, 0x57, 0x0A, 0x55]
        return [
            Data(),
            Data([0x0A]),
            Data([0x00]),
            Data([0xFF]),
            Data([0x0A, 0x02, 0x08, 0x01]),
            Data(objectLengthPrefix + Array(repeating: 0x61, count: 117)),
            Data(arrayLengthPrefix + Array(repeating: 0x61, count: 85))
        ]
    }


    // MARK: - Recovered payloads

    @Test(arguments: [
        Data("{}".utf8),
        Data("[]".utf8),
        Data("{\"resourceSpans\":[]}".utf8),
        Data("{\n  \"resourceSpans\": []\n}".utf8)
    ])
    func fileWithNoTaskDescriptionAndJSONPayloadUsesJSONFormat(jsonPayload: Data) throws {
        let uuid = UUID()
        let disk = MockDiskStorage()
        let http = MockHTTPClient()
        let exporter = try makeExporter(disk: disk, http: http)
        let fileKey = exporter.getStorageKey().append(uuid.uuidString).key
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("otlp-json-\(uuid.uuidString)")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        try jsonPayload.write(to: fileURL)
        disk.files[fileKey] = fileURL

        exporter.checkAndSend(fileKeys: [uuid.uuidString], existingTasks: [], cancelledTaskIds: [])

        #expect(http.sent.count == 1)
        #expect(http.sent.first?.id == uuid)
        #expect(http.sent.first?.payloadFormat == .json)
        #expect(http.sent.first?.createRequest().value(forHTTPHeaderField: "Content-Type") == "application/json")
    }

    @Test(arguments: [Data("{".utf8), Data("[".utf8), Data("{invalid body".utf8), Data("[invalid body".utf8)])
    func payloadWithJSONPrefixDoesNotRequireParsingTheBody(payload: Data) throws {
        let uuid = UUID()
        let disk = MockDiskStorage()
        let http = MockHTTPClient()
        let exporter = try makeExporter(disk: disk, http: http)
        let fileKey = exporter.getStorageKey().append(uuid.uuidString).key
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("otlp-prefix-\(uuid.uuidString)")
        defer { try? FileManager.default.removeItem(at: fileURL) }
        try payload.write(to: fileURL)
        disk.files[fileKey] = fileURL

        exporter.checkAndSend(fileKeys: [uuid.uuidString], existingTasks: [], cancelledTaskIds: [])

        #expect(http.sent.count == 1)
        #expect(http.sent.first?.payloadFormat == .json)
        #expect(http.sent.first?.createRequest().value(forHTTPHeaderField: "Content-Type") == "application/json")
    }

    @Test(arguments: Self.protobufPayloads)
    func fileWithNoTaskDescriptionAndProtobufPayloadUsesProtobufFormat(payload: Data) throws {
        let uuid = UUID()
        let disk = MockDiskStorage()
        let http = MockHTTPClient()
        let exporter = try makeExporter(disk: disk, http: http)
        let fileKey = exporter.getStorageKey().append(uuid.uuidString).key
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("otlp-proto-\(uuid.uuidString)")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        try payload.write(to: fileURL)
        disk.files[fileKey] = fileURL

        exporter.checkAndSend(fileKeys: [uuid.uuidString], existingTasks: [], cancelledTaskIds: [])

        #expect(http.sent.count == 1)
        #expect(http.sent.first?.id == uuid)
        #expect(http.sent.first?.payloadFormat == .protobuf)
        #expect(http.sent.first?.createRequest().value(forHTTPHeaderField: "Content-Type") == "application/x-protobuf")
    }

    @Test
    func fileWithNoTaskDescriptionAndStorageErrorUsesJSONFormat() throws {
        let uuid = UUID()
        let disk = MockDiskStorage()
        disk.shouldThrowOnFinalDestination = true
        let http = MockHTTPClient()
        let exporter = try makeExporter(disk: disk, http: http)

        exporter.checkAndSend(fileKeys: [uuid.uuidString], existingTasks: [], cancelledTaskIds: [])

        #expect(http.sent.count == 1)
        #expect(http.sent.first?.payloadFormat == .json)
        #expect(http.sent.first?.createRequest().value(forHTTPHeaderField: "Content-Type") == "application/json")
    }

    @Test
    func fileWithNoTaskDescriptionAndMissingPayloadUsesJSONFormat() throws {
        let uuid = UUID()
        let disk = MockDiskStorage()
        let http = MockHTTPClient()
        let exporter = try makeExporter(disk: disk, http: http)
        let fileKey = exporter.getStorageKey().append(uuid.uuidString).key
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("otlp-missing-\(uuid.uuidString)")
        disk.files[fileKey] = fileURL
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))

        exporter.checkAndSend(fileKeys: [uuid.uuidString], existingTasks: [], cancelledTaskIds: [])

        #expect(http.sent.count == 1)
        #expect(http.sent.first?.payloadFormat == .json)
        #expect(http.sent.first?.createRequest().value(forHTTPHeaderField: "Content-Type") == "application/json")
    }


    // MARK: - File handle ownership and bounded reads

    @Test(arguments: [
        (Data("{\"resourceSpans\":[]}".utf8), RequestPayloadFormat.json),
        (Data("[{}]".utf8), RequestPayloadFormat.json),
        (Data([0x0A, 0x02, 0x08, 0x01]), RequestPayloadFormat.protobuf),
        (Data(), RequestPayloadFormat.protobuf)
    ])
    func payloadDetectionReadsOnlyOneByteAndClosesHandle(payload: Data, expectedFormat: RequestPayloadFormat) throws {
        let exporter = try makeExporter(disk: MockDiskStorage(), http: MockHTTPClient())
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("otlp-read-limit-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: fileURL) }
        try payload.write(to: fileURL)
        let fileHandle = try FileHandle(forReadingFrom: fileURL)
        defer { try? fileHandle.close() }

        // dup shares the offset, so it can observe the read after the owned handle is closed.
        let observerDescriptor = dup(fileHandle.fileDescriptor)
        try #require(observerDescriptor >= 0)
        let observer = FileHandle(fileDescriptor: observerDescriptor, closeOnDealloc: true)
        defer { try? observer.close() }

        #expect(exporter.inferPayloadFormat(from: fileHandle) == expectedFormat)

        #expect(try observer.offset() == (payload.isEmpty ? 0 : 1))
        #expect(throws: (any Error).self) { try fileHandle.offset() }
    }

    @Test
    func payloadReadFailureUsesJSONFormatAndClosesHandle() throws {
        let exporter = try makeExporter(disk: MockDiskStorage(), http: MockHTTPClient())
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("otlp-read-error-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: fileURL) }
        try Data("{}".utf8).write(to: fileURL)
        let fileHandle = try FileHandle(forWritingTo: fileURL)
        defer { try? fileHandle.close() }

        // The handle is open, but a write-only descriptor deterministically fails a read.
        #expect(try fileHandle.offset() == 0)
        #expect(throws: (any Error).self) { try fileHandle.read(upToCount: 1) }

        #expect(exporter.inferPayloadFormat(from: fileHandle) == .json)

        #expect(throws: (any Error).self) { try fileHandle.offset() }
    }
}
