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
        config: OTLPExporterConfiguration = OTLPExporterConfiguration(),
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
            performStalledUploadCheck: false
        )
        exporter.httpClient = http
        return exporter
    }

    func makeSpanData(count: Int) -> [SpanData] {
        let tracerProvider = TracerProviderBuilder().build()
        let tracer = tracerProvider.get(instrumentationName: "OTLPBackgroundHTTPTraceExporterTests")

        return (0 ..< count)
            .compactMap { index in
                let span = tracer.spanBuilder(spanName: "batch-span-\(index)").startSpan()
                span.end()
                return (span as? ReadableSpan)?.toSpanData()
            }
    }


    // MARK: - Tests

    // Note: Testing with actual SpanData is limited because SDK span types
    // have internal initializers. These tests focus on exporter behavior with
    // empty payloads and infrastructure (flush, shutdown, headers).

    @Test
    func exportEmptySpansReturnsSuccessWithoutSending() throws {
        let disk = makeDisk(uniqueLabel: "empty_spans_\(UUID().uuidString)")
        let http = MockHTTPClient()
        let exporter = try makeExporter(disk: disk, http: http, config: OTLPExporterConfiguration(timeout: 2))

        // Empty spans should return success but not send anything (empty envelope filtering)
        let result = exporter.export(spans: [], explicitTimeout: nil)

        #expect(result == .success)
        #expect(http.sent.isEmpty)
    }

    @Test
    func exportBatchCreatesOneDiskWriteAndUploadRequest() throws {
        let disk = MockDiskStorage()
        let http = MockHTTPClient()
        let exporter = try makeExporter(disk: disk, http: http)

        let result = exporter.export(spans: makeSpanData(count: 100), explicitTimeout: nil)

        #expect(result == .success)
        #expect(disk.insertedKeys.count == 1)
        #expect(http.sent.count == 1)
    }

    @Test
    func pendingTracePayloadSurvivesExporterReplacement() throws {
        let disk = makeDisk(uniqueLabel: "upgrade_\(UUID().uuidString)")
        let oldHTTPClient = MockHTTPClient()
        let oldExporter = OTLPBackgroundHTTPTraceExporter(
            endpoint: nil,
            qosConfig: SessionQOSConfiguration(),
            envVarHeaders: nil,
            diskStorage: disk,
            performStalledUploadCheck: false
        )
        oldExporter.httpClient = oldHTTPClient

        let exportResult = oldExporter.export(spans: makeSpanData(count: 1), explicitTimeout: nil)
        #expect(exportResult == .success)
        #expect(oldHTTPClient.sent.isEmpty)

        let newHTTPClient = MockHTTPClient()
        let newExporter = OTLPBackgroundHTTPTraceExporter(
            endpoint: nil,
            qosConfig: SessionQOSConfiguration(),
            envVarHeaders: nil,
            diskStorage: disk,
            performStalledUploadCheck: false
        )
        newExporter.httpClient = newHTTPClient
        try newExporter.setEndpoint(#require(URL(string: "https://example.com/v1/traces")))

        #expect(newHTTPClient.sent.count == 1)
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
    func shutdownIsNoOp() throws {
        let disk = makeDisk(uniqueLabel: "shutdown_\(UUID().uuidString)")
        let http = MockHTTPClient()
        let exporter = try makeExporter(disk: disk, http: http)

        // Should not throw or deadlock
        exporter.shutdown(explicitTimeout: nil)

        // Exporter still usable after shutdown no-op
        let result = exporter.export(spans: [], explicitTimeout: nil)
        #expect(result == .success)
    }
}
