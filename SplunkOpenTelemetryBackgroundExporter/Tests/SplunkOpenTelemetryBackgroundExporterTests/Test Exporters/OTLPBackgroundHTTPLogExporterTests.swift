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
import OpenTelemetryApi
import OpenTelemetryProtocolExporterCommon
import OpenTelemetrySdk
import Testing
@testable import SplunkOpenTelemetryBackgroundExporter

@Suite
struct OTLPBackgroundHTTPLogExporterTests {

    // MARK: - Helpers

    func makeDisk(uniqueLabel: String) -> DiskStorage {
        FilesystemDiskStorage(
            prefix: FilesystemPrefix(module: "OTLPBackgroundHTTPLogExporterTests.\(uniqueLabel)"),
            rules: Rules(
                relativeUsedSize: 0.2,
                absoluteUsedSize: .init(value: 200, unit: .megabytes)
            ),
            encryption: NoneEncryption()
        )
    }

    func makeFailingDisk(uniqueLabel _: String) -> DiskStorage {
        let diskStorage = MockDiskStorage()
        diskStorage.shouldThrowOnlist = true
        diskStorage.shouldThrowOnInsert = true
        diskStorage.shouldThrowOnFinalDestination = true
        return diskStorage
    }

    func makeExporter(
        disk: DiskStorage,
        http: BackgroundHTTPClientProtocol,
        config: OtlpConfiguration = OtlpConfiguration(),
        fileType: String? = nil,
        headers: [String: String] = [:]
    ) throws -> OTLPBackgroundHTTPLogExporter {
        let endpoint = try #require(URL(string: "https://example.com"))
        let exporter = OTLPBackgroundHTTPLogExporter(
            endpoint: endpoint,
            config: config,
            qosConfig: SessionQOSConfiguration(),
            envVarHeaders: nil,
            headers: headers,
            diskStorage: disk,
            fileType: fileType,
            performStalledUploadCheck: false
        )
        exporter.httpClient = http
        return exporter
    }

    func makeLogRecord() -> ReadableLogRecord {
        let resource = Resource(attributes: [:])
        let scope = InstrumentationScopeInfo(name: "test", version: "1.0.0")
        return ReadableLogRecord(
            resource: resource,
            instrumentationScopeInfo: scope,
            timestamp: Date(),
            observedTimestamp: nil,
            spanContext: nil,
            severity: nil,
            body: nil,
            attributes: ["key": .string("value")]
        )
    }


    // MARK: - Tests

    @Test
    func exportSuccessSendsRequestAndStoresFileWithLogsFileType() throws {
        let disk = makeDisk(uniqueLabel: "export_success_\(UUID().uuidString)")
        let http = MockHTTPClient()
        let config = OtlpConfiguration(timeout: 3)
        let exporter = try makeExporter(disk: disk, http: http, config: config)

        let result = exporter.export(logRecords: [makeLogRecord()], explicitTimeout: nil)

        #expect(result == .success)
        #expect(http.sent.count == 1)

        let sent = try #require(http.sent.first)
        #expect(sent.fileKeyType == "logs")
        #expect(sent.explicitTimeout == config.timeout)

        // File should exist on disk under the expected key
        let fileKey = exporter.getStorageKey().append(sent.id.uuidString)
        let finalURL = try disk.finalDestination(forKey: fileKey)
        #expect(FileManager.default.fileExists(atPath: finalURL.path))
    }

    @Test
    func exportIncludesProvidedHeaders() throws {
        let disk = makeDisk(uniqueLabel: "export_headers_\(UUID().uuidString)")
        let http = MockHTTPClient()
        let token = "log-token"
        let exporter = try makeExporter(
            disk: disk,
            http: http,
            headers: ["X-SF-Token": token]
        )

        let result = exporter.export(logRecords: [makeLogRecord()], explicitTimeout: nil)

        #expect(result == .success)
        let sent = try #require(http.sent.first)
        #expect(sent.headers["X-SF-Token"] == token)
    }

    @Test
    func exportRespectsExplicitTimeoutSmallerThanConfig() throws {
        let disk = makeDisk(uniqueLabel: "timeout_smaller_\(UUID().uuidString)")
        let http = MockHTTPClient()
        let exporter = try makeExporter(disk: disk, http: http, config: OtlpConfiguration(timeout: 10))

        let result = exporter.export(logRecords: [makeLogRecord()], explicitTimeout: 1)

        #expect(result == .success)
        let sent = try #require(http.sent.first)
        #expect(sent.explicitTimeout == 1)
    }

    @Test
    func exportRespectsExplicitTimeoutGreaterThanConfigUsesConfigTimeout() throws {
        let disk = makeDisk(uniqueLabel: "timeout_greater_\(UUID().uuidString)")
        let http = MockHTTPClient()
        let config = OtlpConfiguration(timeout: 2)
        let exporter = try makeExporter(disk: disk, http: http, config: config)

        let result = exporter.export(logRecords: [makeLogRecord()], explicitTimeout: 10)

        #expect(result == .success)
        let sent = try #require(http.sent.first)
        #expect(sent.explicitTimeout == config.timeout)
    }

    @Test
    func exportFailingDiskStorageReturnsFailure() throws {
        let disk = makeFailingDisk(uniqueLabel: "failing_disk_\(UUID().uuidString)")
        let http = MockHTTPClient()
        let exporter = try makeExporter(disk: disk, http: http, config: OtlpConfiguration(timeout: 2))

        let result = exporter.export(logRecords: [makeLogRecord()], explicitTimeout: 10)

        #expect(result == .failure)
        #expect(http.sent.isEmpty)
    }

    @Test
    func exportFailureWhenHTTPClientThrowsKeepsFileOnDiskAndReturnsFailure() throws {
        let disk = makeDisk(uniqueLabel: "http_throw_\(UUID().uuidString)")
        let http = ThrowingHTTPClient()
        let exporter = try makeExporter(disk: disk, http: http, config: OtlpConfiguration(timeout: 5))

        let result = exporter.export(logRecords: [makeLogRecord()], explicitTimeout: nil)

        #expect(result == .failure)

        // Verify at least one file exists under the storage key namespace.
        let entries = try disk.list(forKey: exporter.getStorageKey())
        #expect(!entries.isEmpty)
    }

    @Test
    func exportUsesCustomFileTypeWhenProvidedOnInit() throws {
        let disk = makeDisk(uniqueLabel: "custom_filetype_\(UUID().uuidString)")
        let http = MockHTTPClient()
        let exporter = try makeExporter(disk: disk, http: http, config: OtlpConfiguration(), fileType: "custom_logs")

        let result = exporter.export(logRecords: [makeLogRecord()], explicitTimeout: nil)

        #expect(result == .success)
        let sent = try #require(http.sent.first)
        #expect(sent.fileKeyType == "custom_logs")
    }

    @Test
    func forceFlushCallsHTTPClientFlushAndReturnsSuccess() throws {
        let disk = makeDisk(uniqueLabel: "flush_\(UUID().uuidString)")
        let http = FlushSpyHTTPClient()
        let exporter = try makeExporter(disk: disk, http: http)

        let result = exporter.forceFlush(explicitTimeout: nil)

        #expect(result == .success)
        #expect(http.flushed == true)
    }

    @Test
    func shutdownIsNoOp() throws {
        let disk = makeDisk(uniqueLabel: "shutdown_\(UUID().uuidString)")
        let http = MockHTTPClient()
        let exporter = try makeExporter(disk: disk, http: http)

        // Should not throw or deadlock
        exporter.shutdown(explicitTimeout: nil)

        // Sanity: exporter still usable after shutdown no-op
        let result = exporter.export(logRecords: [makeLogRecord()], explicitTimeout: nil)
        #expect(result == .success)
    }
}
