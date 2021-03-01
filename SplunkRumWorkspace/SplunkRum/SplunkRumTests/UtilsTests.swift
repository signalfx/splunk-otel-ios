//
/*
Copyright 2021 Splunk Inc.

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
import XCTest
@testable import SplunkRum

class UtilsTests: XCTestCase {

    func testSessionId() throws {
        let s1 = generateNewSessionId()
        let s2 = generateNewSessionId()
        XCTAssertNotEqual(s1, s2)
        XCTAssertEqual(s1.count, 32)
        for char in s1 {
            XCTAssertTrue(("0"..."9").contains(char) || ("a"..."f").contains(char))
        }
    }
}
