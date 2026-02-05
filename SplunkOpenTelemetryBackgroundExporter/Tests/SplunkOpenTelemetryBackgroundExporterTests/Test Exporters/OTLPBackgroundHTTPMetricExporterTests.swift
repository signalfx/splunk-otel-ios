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
import OpenTelemetrySdk
import Testing

@testable import SplunkOpenTelemetryBackgroundExporter

@Suite
struct OTLPBackgroundHTTPMetricExporterTests {

    // MARK: - Helpers

    func makeDisk(uniqueLabel: String) -> DiskStorage {
        FilesystemDiskStorage(
            prefix: FilesystemPrefix(module: "OTLPBackgroundHTTPMetricExporterTests.\(uniqueLabel)"),
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
        fileType: String? = nil
    ) throws -> OTLPBackgroundHTTPMetricExporter {
        let endpoint = try #require(URL(string: "https://example.com"))
        let exporter = OTLPBackgroundHTTPMetricExporter(
            endpoint: endpoint,
            config: config,
            qosConfig: SessionQOSConfiguration(),
            envVarHeaders: nil,
            diskStorage: disk,
            fileType: fileType,
            performStalledUploadCheck: false
        )
        exporter.httpClient = http
        return exporter
    }


    // MARK: - Tests

    // Note: Testing with actual MetricData is limited because SDK metric types
    // have internal initializers. These tests focus on exporter behavior with
    // empty payloads and infrastructure (flush, shutdown, temporality).

    @Test
    func exportEmptyMetricsReturnsSuccessWithoutSending() throws {
        let disk = makeDisk(uniqueLabel: "empty_metrics_\(UUID().uuidString)")
        let http = MockHTTPClient()
        let exporter = try makeExporter(disk: disk, http: http, config: OTLPExporterConfiguration(timeout: 2))

        // Empty metrics should return success but not send anything (empty envelope filtering)
        let result = exporter.export(metrics: [])

        #expect(result == .success)
        #expect(http.sent.isEmpty)
    }

    @Test
    func flushCallsHTTPClientFlushAndReturnsSuccess() throws {
        let disk = makeDisk(uniqueLabel: "flush_\(UUID().uuidString)")
        let http = FlushSpyHTTPClient()
        let exporter = try makeExporter(disk: disk, http: http)

        let result = exporter.flush()

        #expect(result == .success)
        #expect(http.flushed == true)
    }

    @Test
    func shutdownReturnsSuccess() throws {
        let disk = makeDisk(uniqueLabel: "shutdown_\(UUID().uuidString)")
        let http = MockHTTPClient()
        let exporter = try makeExporter(disk: disk, http: http)

        let shutdownResult = exporter.shutdown()
        #expect(shutdownResult == .success)
    }

    @Test
    func getAggregationTemporalityReturnsDelta() throws {
        let disk = makeDisk(uniqueLabel: "temporality_\(UUID().uuidString)")
        let http = MockHTTPClient()
        let exporter = try makeExporter(disk: disk, http: http)

        let temporality = exporter.getAggregationTemporality(for: .counter)
        #expect(temporality == .delta)
    }
}
