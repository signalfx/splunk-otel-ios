//
/*
Copyright 2024 Splunk Inc.

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

final class NanoIDTests: XCTestCase {

    // MARK: - Tests

    func testNanoID() throws {
        // Check the format of the generated ID
        let firstSampleId = String.uniqueIdentifier()
        try NanoIDValidator.checkFormat(firstSampleId)

        // Each generated ID must be unique
        let secondSampleId = String.uniqueIdentifier()
        let thirdSampleId = String.uniqueIdentifier()
        XCTAssertNotEqual(firstSampleId, secondSampleId)
        XCTAssertNotEqual(secondSampleId, thirdSampleId)
        XCTAssertNotEqual(thirdSampleId, firstSampleId)

        // Shorter IDs must have a corresponding length
        let shorterId = String.uniqueIdentifier(ofLength: 12)
        XCTAssertTrue(shorterId.count == 12)
    }
}
