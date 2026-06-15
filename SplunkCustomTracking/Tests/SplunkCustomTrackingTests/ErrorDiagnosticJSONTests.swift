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

import XCTest

@testable import SplunkCustomTracking

final class ErrorDiagnosticJSONTests: XCTestCase {

    func testNormalizeFlatErrorDiagnosticKeysDict() throws {
        let input: [ErrorDiagnosticKeys: Any] = [
            .imagePath: "/usr/lib/libSystem.B.dylib",
            .baseAddress: UInt64(0x1000)
        ]

        let normalized = ErrorDiagnosticJSON.normalizeToJSONReady(input) as? [String: Any]

        let result = try XCTUnwrap(normalized)
        XCTAssertEqual(result["imagePath"] as? String, "/usr/lib/libSystem.B.dylib")
        XCTAssertEqual(result["baseAddress"] as? UInt64, UInt64(0x1000))
    }

    func testConvertToJSONStringProducesValidJSON() throws {
        let input: [ErrorDiagnosticKeys: Any] = [
            .imagePath: "MyApp",
            .imageSize: UInt64(4_096)
        ]

        let jsonString = try XCTUnwrap(ErrorDiagnosticJSON.convertToJSONString(input))
        let data = try XCTUnwrap(jsonString.data(using: .utf8))
        let parsed = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(parsed["imagePath"] as? String, "MyApp")
        XCTAssertEqual(parsed["imageSize"] as? Int, 4_096)
    }
}
