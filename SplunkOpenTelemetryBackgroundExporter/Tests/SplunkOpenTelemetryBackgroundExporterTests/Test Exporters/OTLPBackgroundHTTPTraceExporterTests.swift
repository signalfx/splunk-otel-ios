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

    func makeSpanData(name: String = "test-span") -> SpanData {
        let exporter = NoOpSpanExporter()
        let processor = SimpleSpanProcessor(spanExporter: exporter)
        let tracerProvider = TracerProviderBuilder()
            .add(spanProcessor: processor)
            .build()
        let tracer = tracerProvider.get(instrumentationName: "trace-exporter-test", instrumentationVersion: "1.0")
        let span = tracer.spanBuilder(spanName: name).startSpan()
        span.end()

        guard let readableSpan = span as? ReadableSpan else {
            fatalError("Could not get SpanData from span")
        }

        return readableSpan.toSpanData()
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
    func exportReturnsSuccessWhenSchedulingFailsAfterPersistingBatch() throws {
        let disk = makeDisk(uniqueLabel: "http_throw_\(UUID().uuidString)")
        let http = ThrowingHTTPClient()
        let exporter = try makeExporter(disk: disk, http: http, config: OTLPExporterConfiguration(timeout: 5))

        let result = exporter.export(spans: [makeSpanData()], explicitTimeout: nil)

        #expect(result == .success)

        let entries = try disk.list(forKey: exporter.getStorageKey())
        #expect(entries.count == 1)
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
    func forceFlushReturnsFailureWhenHTTPClientDoesNotCompleteBeforeTimeout() throws {
        let disk = makeDisk(uniqueLabel: "flush_timeout_\(UUID().uuidString)")
        let http = MockHTTPClient()
        let exporter = try makeExporter(
            disk: disk,
            http: http,
            config: OTLPExporterConfiguration(timeout: 0.01)
        )
        let start = Date()

        let result = exporter.flush(explicitTimeout: 0.01)

        #expect(result == .failure)
        #expect(Date().timeIntervalSince(start) < 1)
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


private final class NoOpSpanExporter: SpanExporter {
    func export(spans _: [SpanData], explicitTimeout _: TimeInterval?) -> SpanExporterResultCode {
        .success
    }

    func flush(explicitTimeout _: TimeInterval?) -> SpanExporterResultCode {
        .success
    }

    func shutdown(explicitTimeout _: TimeInterval?) {}
}
