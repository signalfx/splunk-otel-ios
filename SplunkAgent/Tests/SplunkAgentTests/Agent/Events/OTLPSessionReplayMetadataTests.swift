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
import XCTest

@testable import SplunkOpenTelemetry

final class OTLPSessionReplayMetadataTests: XCTestCase {

    // MARK: - Tests

    func testReactNativeVersionDisablesWireframe() throws {
        let metadata = try updatedMetadata(globalAttributes: [
            "app.framework.rn.version": .string("1.0")
        ])

        XCTAssertEqual(metadata["displayWireframe"] as? Bool, false)
    }

    func testFlutterVersionDisablesWireframe() throws {
        let metadata = try updatedMetadata(globalAttributes: [
            "app.framework.flutter.version": .string("1.0")
        ])

        XCTAssertEqual(metadata["displayWireframe"] as? Bool, false)
    }

    func testNonHybridMetadataIsUnchanged() {
        let result = OTLPSessionReplayMetadata.metadataByAddingDisplayWireframe(
            to: #"{"source":"native"}"#,
            globalAttributes: ["app.version": .string("1.0")]
        )

        XCTAssertNil(result)
    }

    func testExistingMetadataIsPreservedWhenDisablingWireframe() throws {
        let metadata = try updatedMetadata(
            from: #"{"source":"native","displayWireframe":true}"#,
            globalAttributes: ["app.framework.rn.version": .string("1.0")]
        )

        XCTAssertEqual(metadata["source"] as? String, "native")
        XCTAssertEqual(metadata["displayWireframe"] as? Bool, false)
    }


    // MARK: - Private

    private func updatedMetadata(
        from metadataJSON: String = #"{"source":"native"}"#,
        globalAttributes: [String: AttributeValue]
    ) throws -> [String: Any] {
        let updatedMetadata = try XCTUnwrap(
            OTLPSessionReplayMetadata.metadataByAddingDisplayWireframe(
                to: metadataJSON,
                globalAttributes: globalAttributes
            )
        )
        let updatedData = try XCTUnwrap(updatedMetadata.data(using: .utf8))

        return try XCTUnwrap(JSONSerialization.jsonObject(with: updatedData) as? [String: Any])
    }
}
