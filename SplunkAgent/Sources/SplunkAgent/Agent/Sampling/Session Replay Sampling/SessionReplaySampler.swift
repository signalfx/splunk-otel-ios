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

/// A concrete `StatisticalSampler` for Session Replay sampling.
///
/// Determines whether the Session Replay recording should be enabled
/// for the current app launch based on the configured probability.
///
/// The sampling decision is calculated once per Agent lifecycle and does not
/// re-evaluate on session rotation.
final class SessionReplaySampler: StatisticalSampler {

    // MARK: - StatisticalSampler Conformance

    /// The upper bound for random number generation, fixed at 1.0.
    let upperBound: Double = 1.0

    /// The lower bound for random number generation, fixed at 0.0.
    let lowerBound: Double = 0.0

    /// The probability of enabling Session Replay recording.
    ///
    /// - `0.0` means Session Replay is always disabled.
    /// - `1.0` means Session Replay is always enabled.
    /// - Values in between represent the probability of enabling recording.
    let probability: Double


    // MARK: - Initialization

    /// Creates a new Session Replay sampler with the given probability.
    ///
    /// - Parameter probability: A value in the `[0.0, 1.0]` range representing
    ///   the probability of enabling Session Replay recording. Values outside
    ///   this range should be clamped before passing to this initializer.
    init(probability: Double) {
        self.probability = probability
    }
}
