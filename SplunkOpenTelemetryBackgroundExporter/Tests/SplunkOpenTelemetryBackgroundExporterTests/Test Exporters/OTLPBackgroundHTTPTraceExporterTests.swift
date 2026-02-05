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
import OpenTelemetrySdk
import Testing

@testable import SplunkOpenTelemetryBackgroundExporter

@Suite
struct OTLPBackgroundHTTPTraceExporterTests {

    // MARK: - Helpers

    func makeDisk(uniqueLabel: String) -> DiskStorage {
        FilesystemDiskStorage(
            prefix: FilesystemPrefix(module: "OTLPBackgroundHTTPTraceExporterTests.\(uniqueLabel)"),
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
    ) throws -> OTLPBackgroundHTTPTraceExporter {
        let endpoint = try #require(URL(string: "https://example.com"))
        let exporter = OTLPBackgroundHTTPTraceExporter(
            endpoint: endpoint,
            config: config,
            qosConfig: SessionQOSConfiguration(),
            envVarHeaders: nil,
            headers: headers,
            diskStorage: disk,
            fileType: fileType,
            performStalledUploadCheck: false,
            httpClient: http
        )
        return exporter
    }


    // MARK: - Tests

    @Test
    func exportSuccessSendsRequestAndStoresFileWithTraceFileType() throws {
        let disk = makeDisk(uniqueLabel: "export_success_\(UUID().uuidString)")
        let http = MockHTTPClient()
        let config = OtlpConfiguration(timeout: 3)
        let exporter = try makeExporter(disk: disk, http: http, config: config)

        let result = exporter.export(spans: [], explicitTimeout: nil)

        #expect(result == .success)
        #expect(http.sent.count == 1)

        let sent = try #require(http.sent.first)
        #expect(sent.fileKeyType == "trace")
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
        let token = "trace-token"
        let exporter = try makeExporter(
            disk: disk,
            http: http,
            headers: ["X-SF-Token": token]
        )

        let result = exporter.export(spans: [], explicitTimeout: nil)

        #expect(result == .success)
        let sent = try #require(http.sent.first)
        #expect(sent.headers["X-SF-Token"] == token)
    }

    @Test
    func exportRespectsExplicitTimeoutSmallerThanConfig() throws {
        let disk = makeDisk(uniqueLabel: "timeout_smaller_\(UUID().uuidString)")
        let http = MockHTTPClient()
        let exporter = try makeExporter(disk: disk, http: http, config: OtlpConfiguration(timeout: 10))

        let result = exporter.export(spans: [], explicitTimeout: 1)

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

        let result = exporter.export(spans: [], explicitTimeout: 10)

        #expect(result == .success)
        let sent = try #require(http.sent.first)
        #expect(sent.explicitTimeout == config.timeout)
    }

    @Test
    func exportFailingDiskStorageReturnsFailureAndDoesNotSend() throws {
        let disk = makeFailingDisk(uniqueLabel: "failing_disk_\(UUID().uuidString)")
        let http = MockHTTPClient()
        let exporter = try makeExporter(disk: disk, http: http, config: OtlpConfiguration(timeout: 2))

        let result = exporter.export(spans: [], explicitTimeout: 10)

        #expect(result == .failure)
        #expect(http.sent.isEmpty)
    }

    @Test
    func exportFailureWhenHTTPClientThrowsKeepsFileOnDiskAndReturnsFailure() throws {
        let disk = makeDisk(uniqueLabel: "http_throw_\(UUID().uuidString)")
        let http = ThrowingHTTPClient()
        let exporter = try makeExporter(disk: disk, http: http, config: OtlpConfiguration(timeout: 5))

        let result = exporter.export(spans: [], explicitTimeout: nil)

        #expect(result == .failure)

        // Verify at least one file exists under the storage key namespace.
        let entries = try disk.list(forKey: exporter.getStorageKey())
        #expect(!entries.isEmpty)
    }

    @Test
    func exportUsesCustomFileTypeWhenProvidedOnInit() throws {
        let disk = makeDisk(uniqueLabel: "custom_filetype_\(UUID().uuidString)")
        let http = MockHTTPClient()
        let exporter = try makeExporter(disk: disk, http: http, config: OtlpConfiguration(), fileType: "custom_trace")

        let result = exporter.export(spans: [], explicitTimeout: nil)

        #expect(result == .success)
        let sent = try #require(http.sent.first)
        #expect(sent.fileKeyType == "custom_trace")
    }

    @Test
    func forceFlushCallsHTTPClientFlushAndReturnsSuccess() throws {
        let disk = makeDisk(uniqueLabel: "flush_\(UUID().uuidString)")
        let http = FlushSpyHTTPClient()
        let exporter = try makeExporter(disk: disk, http: http)

        let result = exporter.flush(explicitTimeout: nil)

        #expect(result == .success)
        #expect(http.flushed == true)
    }

    @Test
    func shutdownIsNoOpAndExporterRemainsUsable() throws {
        let disk = makeDisk(uniqueLabel: "shutdown_\(UUID().uuidString)")
        let http = MockHTTPClient()
        let exporter = try makeExporter(disk: disk, http: http)

        // Should not throw or deadlock
        exporter.shutdown(explicitTimeout: nil)

        // Sanity: exporter still usable after shutdown no-op
        let result = exporter.export(spans: [], explicitTimeout: nil)
        #expect(result == .success)
    }


    // MARK: - Pending Endpoint Tests

    @Test
    func exportWithNilEndpointCachesDataInPendingStorage() throws {
        let disk = makeDisk(uniqueLabel: "nil_endpoint_\(UUID().uuidString)")
        let http = MockHTTPClient()

        // Create exporter with nil endpoint
        let exporter = OTLPBackgroundHTTPTraceExporter(
            endpoint: nil,
            config: OtlpConfiguration(),
            qosConfig: SessionQOSConfiguration(),
            envVarHeaders: nil,
            headers: [:],
            diskStorage: disk,
            fileType: nil,
            performStalledUploadCheck: false,
            httpClient: http
        )

        // Export should succeed
        let result = exporter.export(spans: [], explicitTimeout: nil)
        #expect(result == .success)

        // HTTP client should NOT have been called (no endpoint)
        #expect(http.sent.isEmpty)

        // Data should be in pending storage
        #expect(exporter.isPendingEndpoint == true)
        let pendingEntries = try disk.list(forKey: exporter.getPendingStorageKey())
        #expect(!pendingEntries.isEmpty)

        // Active storage should be empty
        let activeEntries = try disk.list(forKey: exporter.getStorageKey())
        #expect(activeEntries.isEmpty)
    }

    @Test
    func initWithEndpointFlushesPendingData() throws {
        let disk = makeDisk(uniqueLabel: "set_endpoint_\(UUID().uuidString)")

        // Create exporter with nil endpoint
        let pendingExporter = OTLPBackgroundHTTPTraceExporter(
            endpoint: nil,
            config: OtlpConfiguration(),
            qosConfig: SessionQOSConfiguration(),
            envVarHeaders: nil,
            headers: [:],
            diskStorage: disk,
            fileType: nil,
            performStalledUploadCheck: false
        )

        // Export some data (will be cached)
        _ = pendingExporter.export(spans: [], explicitTimeout: nil)
        _ = pendingExporter.export(spans: [], explicitTimeout: nil)

        // Verify data is pending
        let pendingBeforeSet = try disk.list(forKey: pendingExporter.getPendingStorageKey())
        #expect(pendingBeforeSet.count == 2)

        let http = MockHTTPClient()

        // Create exporter with endpoint to flush pending data
        let endpoint = try #require(URL(string: "https://example.com/traces"))
        let exporter = OTLPBackgroundHTTPTraceExporter(
            endpoint: endpoint,
            config: OtlpConfiguration(),
            qosConfig: SessionQOSConfiguration(),
            envVarHeaders: nil,
            headers: [:],
            diskStorage: disk,
            fileType: nil,
            performStalledUploadCheck: false,
            httpClient: http
        )

        // After initializing with endpoint, isPendingEndpoint should be false
        #expect(exporter.isPendingEndpoint == false)

        // HTTP client should have received the flushed requests
        #expect(http.sent.count == 2)

        // Pending storage should be empty (data moved to active)
        let pendingAfterSet = try disk.list(forKey: exporter.getPendingStorageKey())
        #expect(pendingAfterSet.isEmpty)
    }

    @Test
    func exportWithEndpointSendsImmediately() throws {
        let disk = makeDisk(uniqueLabel: "export_after_set_\(UUID().uuidString)")
        let http = MockHTTPClient()

        // Create exporter with endpoint
        let endpoint = try #require(URL(string: "https://example.com/traces"))
        let exporter = OTLPBackgroundHTTPTraceExporter(
            endpoint: endpoint,
            config: OtlpConfiguration(),
            qosConfig: SessionQOSConfiguration(),
            envVarHeaders: nil,
            headers: [:],
            diskStorage: disk,
            fileType: nil,
            performStalledUploadCheck: false,
            httpClient: http
        )

        // Export should now send immediately
        let result = exporter.export(spans: [], explicitTimeout: nil)
        #expect(result == .success)
        #expect(http.sent.count == 1)

        // Pending storage should remain empty
        let pendingEntries = try disk.list(forKey: exporter.getPendingStorageKey())
        #expect(pendingEntries.isEmpty)
    }

    @Test
    func exportWithHeadersUsesConfiguredHeaders() throws {
        let disk = makeDisk(uniqueLabel: "set_endpoint_headers_\(UUID().uuidString)")
        let http = MockHTTPClient()

        // Create exporter with endpoint and headers
        let exporter = OTLPBackgroundHTTPTraceExporter(
            endpoint: try #require(URL(string: "https://example.com/traces")),
            config: OtlpConfiguration(),
            qosConfig: SessionQOSConfiguration(),
            envVarHeaders: nil,
            headers: ["X-SF-Token": "new-token"],
            diskStorage: disk,
            fileType: nil,
            performStalledUploadCheck: false,
            httpClient: http
        )

        // Export and verify headers
        _ = exporter.export(spans: [], explicitTimeout: nil)

        let sent = try #require(http.sent.first)
        #expect(sent.headers["X-SF-Token"] == "new-token")
    }
}
