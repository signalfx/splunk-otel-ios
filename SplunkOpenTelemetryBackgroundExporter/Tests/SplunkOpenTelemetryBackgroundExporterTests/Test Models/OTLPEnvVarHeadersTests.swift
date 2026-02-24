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

import Testing

@testable import SplunkOpenTelemetryBackgroundExporter

@Suite
struct OTLPEnvVarHeadersTests {

    // MARK: - Tests

    @Test
    func parseHeaderListValueDecodesPercentEncodedKeyAndValueComponents() throws {
        let parsed = try #require(
            OTLPEnvVarHeaders.parseHeaderListValue(
                "Authorization=Bearer%20abc%2Cdef%3Dghi,X-SF%2DToken=my%20token"
            )
        )

        #expect(parsed.count == 2)
        #expect(parsed[0].0 == "Authorization")
        #expect(parsed[0].1 == "Bearer abc,def=ghi")
        #expect(parsed[1].0 == "X-SF-Token")
        #expect(parsed[1].1 == "my token")
    }

    @Test
    func parseHeaderListValuePreservesEqualsInDecodedValue() throws {
        let parsed = try #require(
            OTLPEnvVarHeaders.parseHeaderListValue("Authorization=Basic%20dXNlcjpwYXNz%3D%3D")
        )

        #expect(parsed.count == 1)
        #expect(parsed[0].0 == "Authorization")
        #expect(parsed[0].1 == "Basic dXNlcjpwYXNz==")
    }

    @Test
    func parseHeaderListValueKeepsInvalidPercentEncodingVerbatim() throws {
        let parsed = try #require(
            OTLPEnvVarHeaders.parseHeaderListValue("X-Token=abc%ZZ123")
        )

        #expect(parsed.count == 1)
        #expect(parsed[0].0 == "X-Token")
        #expect(parsed[0].1 == "abc%ZZ123")
    }
}
