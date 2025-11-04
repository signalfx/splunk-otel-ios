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

    func testShouldSend_givenThreePreviousAttempts() throws {
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

    func testShouldSend_givenSixPreviousAttempts() throws {
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
}
