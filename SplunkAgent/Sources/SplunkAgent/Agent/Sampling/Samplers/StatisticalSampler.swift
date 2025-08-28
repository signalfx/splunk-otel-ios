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

/// A protocol for samplers that calculate decisions based on statistical probability.
protocol StatisticalSampler: BaseSampler {

    /// The target probability of sampling an item.
    var probability: Double { get }

    /// The upper bound of the interval used for generating random numbers in the sampling decision.
    var upperBound: Double { get }

    /// The lower bound of the interval used for generating random numbers in the sampling decision.
    var lowerBound: Double { get }
}

extension StatisticalSampler {

    // MARK: - Default sampling function implementation

    /// Provides a default sampling decision logic for statistical samplers.
    ///
    /// This implementation compares a randomly generated number against the sampler's `probability`.
    /// - If `probability` is 1.0, it always returns `.notSampledOut`.
    /// - If `probability` is 0.0, it always returns `.sampledOut`.
    /// - Otherwise, it generates a random number within the `[lowerBound, upperBound]` range.
    ///   If this random number is less than or equal to `probability`, it returns `.notSampledOut`, otherwise, it returns `.sampledOut`.
    ///   For miss-configured bounds, it returns `.sampledOut`.
    ///
    /// - Parameter randomNumberProvider: An object conforming to `RandomNumberProvider`
    ///   used to generate the random number. Defaults to `SystemRandomNumberProvider()`.
    /// - Returns: A `SamplingDecision`.
    func sample(randomNumberProvider: RandomNumberProvider = SystemRandomNumberProvider()) -> SamplingDecision {

        // Filter out miss-configured bounds.
        guard lowerBound <= upperBound, lowerBound >= 0.0, upperBound <= 1.0 else {
            return .sampledOut
        }

        // The user-configured sampling rate is 1, meaning we want to record all Agent sessions.
        if probability == 1.0 {
            return .notSampledOut
        }

        // The user-configured sampling rate is 0, meaning we want to record no Agent sessions.
        if probability == 0.0 {
            return .sampledOut
        }

        // For any other value, we want to generate a random constant...
        let randomNumber = randomNumberProvider.randomNumber(in: lowerBound ... upperBound)

        // ... and do a bound comparison against the configured sampling rate.
        if randomNumber <= probability {
            return .notSampledOut
        }

        return .sampledOut
    }

    /// Calculates a sampling decision using the default system random number provider by
    /// calling the default `sample(randomNumberProvider: RandomNumberProvider)` function.
    ///
    /// - Returns: A `SamplingDecision`.
    func sample() -> SamplingDecision {
        sample(randomNumberProvider: SystemRandomNumberProvider())
    }
}
