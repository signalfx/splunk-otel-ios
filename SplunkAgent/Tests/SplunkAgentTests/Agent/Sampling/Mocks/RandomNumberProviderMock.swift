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

import Foundation

@testable import SplunkAgent

class MockRandomNumberProvider: RandomNumberProvider {

    // MARK: - Properties

    var nextRandomNumbers: [Double] = []
    var rangesProvided: [ClosedRange<Double>] = []

    private var currentIndex = 0

    func randomNumber(in range: ClosedRange<Double>) -> Double {
        rangesProvided.append(range)

        if nextRandomNumbers.isEmpty {
            // Fallback if no numbers are provided, though tests should always provide them.
            fatalError("MockRandomNumberProvider: nextRandomNumbers is empty. Test should set this.")
        }

        if currentIndex >= nextRandomNumbers.count {
            fatalError("MockRandomNumberProvider: Not enough random numbers provided for the test.")
        }

        let number = nextRandomNumbers[currentIndex]
        currentIndex += 1

        return number
    }

    func reset() {
        currentIndex = 0
        nextRandomNumbers = []
        rangesProvided = []
    }
}
