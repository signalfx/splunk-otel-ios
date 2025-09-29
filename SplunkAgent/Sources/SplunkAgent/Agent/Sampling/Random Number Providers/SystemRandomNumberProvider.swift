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

/// A protocol designed for objects that can provide random numbers.
protocol RandomNumberProvider {

    /// Generates a random `Double` within the specified inclusive range.
    ///
    /// - Parameters:
    ///   - range: A `ClosedRange<Double>` specifying the lower and upper bounds for the random number.
    /// - Returns: A random `Double` within the specified range.
    func randomNumber(in range: ClosedRange<Double>) -> Double
}

/// A default implementation of `RandomNumberProvider` that utilizes the
/// system's `Double.random(in:)` function for generating random numbers.
///
/// This provider is suitable for most general-purpose statistical samplers.
struct SystemRandomNumberProvider: RandomNumberProvider {

    /// Generates a random `Double` using `Double.random(in: range)`.
    ///
    /// - Parameter range: The inclusive range within which to generate the random number.
    /// - Returns: A random `Double` within the specified range.
    func randomNumber(in range: ClosedRange<Double>) -> Double {
        Double.random(in: range)
    }
}
