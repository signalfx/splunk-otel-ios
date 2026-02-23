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

import XCTest

@testable import SplunkOpenTelemetryBackgroundExporter

final class SplunkRequestDescriptorTests: XCTestCase {

    // MARK: - Private

    private let fileKeyType: String = "logfile"


    // MARK: - Should send tests

    func testShouldSendGivenThreePreviousAttempts() throws {
        let exampleURL = try XCTUnwrap(URL(string: "example.com"))

        var requestDescriotor = RequestDescriptor(
            id: UUID(),
            endpoint: exampleURL,
            explicitTimeout: 0,
            fileKeyType: fileKeyType
        )

        requestDescriotor.sentCount = 3

        XCTAssertTrue(requestDescriotor.shouldSend)
    }

    func testShouldSendGivenSixPreviousAttempts() throws {
        let exampleURL = try XCTUnwrap(URL(string: "example.com"))

        var requestDescriotor = RequestDescriptor(
            id: UUID(),
            endpoint: exampleURL,
            explicitTimeout: 0,
            fileKeyType: fileKeyType
        )

        requestDescriotor.sentCount = 6

        XCTAssertFalse(requestDescriotor.shouldSend)
    }


    // MARK: - Request delay tests

    func testRequestDelay() throws {
        let exampleURL = try XCTUnwrap(URL(string: "example.com"))

        var requestDescriotor = RequestDescriptor(
            id: UUID(),
            endpoint: exampleURL,
            explicitTimeout: 0,
            fileKeyType: fileKeyType
        )

        requestDescriotor.sentCount = 3

        var delay = DateComponents()
        delay.minute = 30
        let expectedSendDate = Calendar.current.date(byAdding: delay, to: Date()) ?? Date()

        // Check the date intervals with an arbitrarily small accuracy.
        XCTAssertEqual(expectedSendDate.timeIntervalSinceReferenceDate, requestDescriotor.scheduled.timeIntervalSinceReferenceDate, accuracy: 0.1)
    }

    func testDecodeWithoutHeadersDefaultsToEmpty() throws {
        let id = UUID()
        let payload: [String: Any] = [
            "id": id.uuidString,
            "endpoint": "https://example.com",
            "explicitTimeout": 1.0,
            "sentCount": 2,
            "fileKeyType": fileKeyType
        ]

        let data = try JSONSerialization.data(withJSONObject: payload, options: [])
        let decoded = try JSONDecoder().decode(RequestDescriptor.self, from: data)

        XCTAssertEqual(decoded.headers, [:])
    }
    
    
    // MARK: - Content-Type migration tests
    
    func testDecodeWithoutContentTypeDefaultsToProtobuf() throws {
        // Simulates pre-2.1.0 RequestDescriptor (no contentType field)
        let id = UUID()
        let payload: [String: Any] = [
            "id": id.uuidString,
            "endpoint": "https://example.com",
            "explicitTimeout": 60.0,
            "sentCount": 0,
            "fileKeyType": fileKeyType,
            "headers": [:]
        ]
        
        let data = try JSONSerialization.data(withJSONObject: payload, options: [])
        let decoded = try JSONDecoder().decode(RequestDescriptor.self, from: data)
        
        // Pre-2.1.0 data should default to protobuf format
        XCTAssertEqual(decoded.contentType, "application/x-protobuf")
        
        let request = decoded.createRequest()
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/x-protobuf")
    }
    
    func testDecodeWithContentTypeUsesStoredValue() throws {
        // Simulates post-2.1.0 RequestDescriptor with explicit contentType
        let id = UUID()
        let payload: [String: Any] = [
            "id": id.uuidString,
            "endpoint": "https://example.com",
            "explicitTimeout": 60.0,
            "sentCount": 0,
            "fileKeyType": fileKeyType,
            "headers": [:],
            "contentType": "application/json"
        ]
        
        let data = try JSONSerialization.data(withJSONObject: payload, options: [])
        let decoded = try JSONDecoder().decode(RequestDescriptor.self, from: data)
        
        XCTAssertEqual(decoded.contentType, "application/json")
        
        let request = decoded.createRequest()
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }
    
    func testNewDescriptorDefaultsToJSON() throws {
        let exampleURL = try XCTUnwrap(URL(string: "https://example.com"))
        
        let descriptor = RequestDescriptor(
            id: UUID(),
            endpoint: exampleURL,
            explicitTimeout: 60.0,
            fileKeyType: fileKeyType
        )
        
        // New descriptors should default to JSON
        XCTAssertEqual(descriptor.contentType, "application/json")
        
        let request = descriptor.createRequest()
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }
    
    func testEncodeDecodeRoundTrip() throws {
        let exampleURL = try XCTUnwrap(URL(string: "https://example.com"))
        
        let original = RequestDescriptor(
            id: UUID(),
            endpoint: exampleURL,
            explicitTimeout: 60.0,
            sentCount: 2,
            fileKeyType: fileKeyType,
            headers: ["X-Custom": "value"],
            contentType: "application/json"
        )
        
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RequestDescriptor.self, from: encoded)
        
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.endpoint, original.endpoint)
        XCTAssertEqual(decoded.explicitTimeout, original.explicitTimeout)
        XCTAssertEqual(decoded.sentCount, original.sentCount)
        XCTAssertEqual(decoded.fileKeyType, original.fileKeyType)
        XCTAssertEqual(decoded.headers, original.headers)
        XCTAssertEqual(decoded.contentType, original.contentType)
    }
}
