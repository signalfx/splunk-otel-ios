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

import Foundation
import Testing

@testable import SplunkOpenTelemetryBackgroundExporter

@Suite
struct OTLPBackgroundExporterEndpointTests {

    @Test
    func settingEndpointDoesNotWaitForPendingDiskScan() throws {
        let disk = MockDiskStorage()
        let scanStarted = DispatchSemaphore(value: 0)
        let resumeScan = DispatchSemaphore(value: 0)
        let callReturned = DispatchSemaphore(value: 0)
        disk.onList = {
            scanStarted.signal()
            resumeScan.wait()
        }
        defer { resumeScan.signal() }

        let exporter = OTLPBackgroundHTTPBaseExporter(
            endpoint: nil,
            qosConfig: SessionQOSConfiguration(),
            envVarHeaders: nil,
            diskStorage: disk,
            performStalledUploadCheck: false
        )
        let endpoint = try #require(URL(string: "https://example.com/v1/traces"))

        DispatchQueue.global()
            .async {
                exporter.setEndpoint(endpoint)
                callReturned.signal()
            }

        #expect(scanStarted.wait(timeout: .now() + 1) == .success)
        #expect(callReturned.wait(timeout: .now() + 0.1) == .success)
        #expect(exporter.endpoint == endpoint)
    }
}
