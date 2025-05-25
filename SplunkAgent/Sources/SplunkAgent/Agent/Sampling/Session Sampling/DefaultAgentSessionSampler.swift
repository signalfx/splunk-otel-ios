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

/// A default concrete implementation of `AgentSessionSampler`.
///
/// It defaults to a sampling rate of 1.0 (sample all sessions) until configured otherwise.
/// The random number generation for sampling decisions uses the `[0.0, 1.0]` bounding interval.
final class DefaultAgentSessionSampler: AgentSessionSampler {

    // MARK: - StatisticalSampler Conformance

    /// The upper bound for random number generation, fixed at 1.0.
    let upperBound: Double = 1.0

    /// The lower bound for random number generation, fixed at 0.0.
    let lowerBound: Double = 0.0

    /// The probability of sampling a session, configurable via the `configure` method.
    /// Defaults to 1.0 (always sample).
    var probability: Double = 1.0


    // MARK: - Configuration

    /// Configures the sampler with the session sampling rate from the provided agent configuration.
    /// - Parameter configuration: An object conforming to `AgentConfigurationProtocol` that
    /// supplies the `sessionSamplingRate`.
    func configure(with configuration: any AgentConfigurationProtocol) {
        probability = configuration.sessionSamplingRate
    }
}
