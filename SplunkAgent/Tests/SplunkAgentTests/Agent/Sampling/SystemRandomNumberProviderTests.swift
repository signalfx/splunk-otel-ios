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

final class SystemRandomNumberProviderTests: XCTestCase {

    var provider: SystemRandomNumberProvider!

    override func setUp() {
        super.setUp()
        provider = SystemRandomNumberProvider()
    }

    override func tearDown() {
        provider = nil
        super.tearDown()
    }

    func testRandomNumberWithinRange() {
        let testRange = 0.25 ... 0.75

        // Silly simulate randomness...
        for _ in 0 ..< 100 {
            let randomNumber = provider.randomNumber(in: testRange)
            XCTAssertGreaterThanOrEqual(randomNumber, testRange.lowerBound)
            XCTAssertLessThanOrEqual(randomNumber, testRange.upperBound)
        }
    }

    func testRandomNumberWithZeroLengthRange() {
        let testRange = 0.5 ... 0.5
        let randomNumber = provider.randomNumber(in: testRange)
        XCTAssertEqual(randomNumber, 0.5)
    }
}
