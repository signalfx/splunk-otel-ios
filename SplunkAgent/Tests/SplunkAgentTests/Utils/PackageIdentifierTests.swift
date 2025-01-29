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

@testable import SplunkAgent
import XCTest

final class PackageIdentifierTests: XCTestCase {

    // MARK: - Tests

    func testIdentification() throws {
        // Static properties (READ)
        let defaultIdentifier = PackageIdentifier.default
        XCTAssertFalse(defaultIdentifier.isEmpty)


        // Identifier method
        let identifierExtension = "test"
        var identifier = PackageIdentifier.default(named: identifierExtension)
        XCTAssertFalse(identifier.isEmpty)

        // Check if the identifier has the expected format
        var expectedIdentifier = "\(defaultIdentifier).\(identifierExtension)"
        XCTAssertEqual(identifier, expectedIdentifier)


        // Checks format for the identifier generated with an empty extension
        let emptyExtension = ""
        expectedIdentifier = defaultIdentifier

        identifier = PackageIdentifier.default(named: emptyExtension)
        XCTAssertEqual(identifier, expectedIdentifier)
    }
}
