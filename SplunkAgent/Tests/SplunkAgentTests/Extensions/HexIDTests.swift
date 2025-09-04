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

@testable import SplunkAgent
import XCTest

final class HexIDTests: XCTestCase {

    // MARK: - Tests

    func testHexID() throws {
        var previousIdentifier: String?

        for _ in 0 ..< 100 {
            let identifier = String.uniqueHexIdentifier()
            try HexIDValidator.checkFormat(identifier)

            if let previousIdentifier {
                XCTAssertTrue(previousIdentifier != identifier)
            }

            previousIdentifier = identifier
        }

        // Shorter IDs must have a corresponding length
        let shorterId = String.uniqueHexIdentifier(ofLength: 12)
        XCTAssertTrue(shorterId.count == 12)

        // Longer IDs must have a corresponding length
        let longerId = String.uniqueHexIdentifier(ofLength: 32)
        XCTAssertTrue(longerId.count == 32)
    }
}
