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
import OpenTelemetryApi
import Testing

@testable import SplunkOpenTelemetryBackgroundExporter

@Suite
struct OTLPEncodingConformanceTests {

    // MARK: - Helpers

    private func makeSpan(flags: UInt32? = nil, kind: Int = 2) -> OTLPSpan {
        OTLPSpan(
            traceId: OTLPTraceId(from: TraceId.random()),
            spanId: OTLPSpanId(from: SpanId.random()),
            name: "test-span",
            kind: kind,
            startTimeUnixNano: OTLPUInt64(1),
            endTimeUnixNano: OTLPUInt64(2),
            flags: flags
        )
    }

    private func decodeJSON(_ data: Data) throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }


    // MARK: - Tests

    @Test
    func traceIdEncodesAsLowercaseHexString() throws {
        let traceId = OTLPTraceId(from: TraceId.random())
        let json = try JSONEncoder().encode(traceId)
        let string = try #require(String(data: json, encoding: .utf8))
        let hex = string.trimmingCharacters(in: CharacterSet(charactersIn: "\""))

        #expect(hex.count == 32)
        #expect(try hex.allSatisfy(\.isHexDigit))
        #expect(hex == hex.lowercased())
    }

    @Test
    func spanIdEncodesAsLowercaseHexString() throws {
        let spanId = OTLPSpanId(from: SpanId.random())
        let json = try JSONEncoder().encode(spanId)
        let string = try #require(String(data: json, encoding: .utf8))
        let hex = string.trimmingCharacters(in: CharacterSet(charactersIn: "\""))

        #expect(hex.count == 16)
        #expect(try hex.allSatisfy(\.isHexDigit))
        #expect(hex == hex.lowercased())
    }

    @Test
    func uint64EncodesAsDecimalString() throws {
        let timestamp = OTLPUInt64(1_544_712_660_000_000_000)
        let json = try JSONEncoder().encode(timestamp)
        let string = try #require(String(data: json, encoding: .utf8))

        #expect(string == "\"1544712660000000000\"")
    }

    @Test
    func int64EncodesAsDecimalString() throws {
        let value = OTLPInt64(-123_456_789)
        let json = try JSONEncoder().encode(value)
        let string = try #require(String(data: json, encoding: .utf8))

        #expect(string == "\"-123456789\"")
    }

    @Test
    func bytesValueEncodesAsBase64() throws {
        let data = Data("Hello".utf8)
        let anyValue = OTLPAnyValue.bytesValue(data)
        let json = try JSONEncoder().encode(anyValue)
        let dict = try decodeJSON(json)

        #expect(dict["bytesValue"] as? String == data.base64EncodedString())
    }

    @Test
    func spanKindEncodesAsInteger() throws {
        let span = makeSpan(kind: 2)
        let json = try JSONEncoder().encode(span)
        let dict = try decodeJSON(json)

        let kind = dict["kind"]
        #expect(kind is NSNumber)
        #expect((kind as? NSNumber)?.intValue == 2)
    }

    @Test
    func flagsZeroIsEncoded() throws {
        let span = makeSpan(flags: 0)
        let json = try JSONEncoder().encode(span)
        let dict = try decodeJSON(json)

        #expect(dict.keys.contains("flags"))
        #expect((dict["flags"] as? NSNumber)?.uintValue == 0)
    }
}
