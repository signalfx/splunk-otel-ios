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
struct OTLPHTTPHeadersTests {

    // MARK: - Tests

    @Test
    func userAgentIdentifiesSplunkRumOSExporterAndOSVersion() {
        let agentVersion = "2.3.1"
        let expectedOSName: String
        #if os(iOS)
            expectedOSName = "iOS"
        #elseif os(tvOS)
            expectedOSName = "tvOS"
        #elseif os(visionOS)
            expectedOSName = "visionOS"
        #elseif os(macOS)
            expectedOSName = "macOS"
        #else
            expectedOSName = "unknown"
        #endif

        let operatingSystemVersion = ProcessInfo.processInfo.operatingSystemVersion
        let expectedOSVersion = "\(operatingSystemVersion.majorVersion).\(operatingSystemVersion.minorVersion).\(operatingSystemVersion.patchVersion)"
        let expectedUserAgent = "SplunkRUM/\(agentVersion) (\(expectedOSName); \(expectedOSVersion)) OTel-OTLP-Exporter-Swift/\(OTLPVersion.version)"

        #expect(OTLPHTTPHeaders.userAgent(agentVersion: agentVersion) == expectedUserAgent)
    }
}
