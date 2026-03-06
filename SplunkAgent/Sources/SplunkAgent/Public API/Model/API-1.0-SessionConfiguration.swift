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

/// A configuration object representing properties of the Agent's `Session`.
public struct SessionConfiguration: Codable, Equatable {

    // MARK: - Public properties

    /// A sampling rate in the `<0.0, 1.0>` interval.
    ///
    /// `1.0` equals to zero sampling (all instrumentation is sent),
    /// `0.0` equals to all session being sampled, `0.5` equals to 50% sampling.
    ///
    /// Defaults to `1.0`.
    public var samplingRate = ConfigurationDefaults.sessionSamplingRate


    // MARK: - Initialization

    /// Default empty constructor.
    ///
    /// Initializes the configuration object's properties with default values.
    public init() {}

    /// Initializes the configuration object.
    ///
    /// - Parameters:
    /// - samplingRate: A sampling rate in the `<0.0, 1.0>` interval.
    /// `1.0` equals to zero sampling (all instrumentation is sent),
    /// `0.0` equals to all session being sampled, `0.5` equals to 50% sampling.
    public init(samplingRate: Double) {
        self.samplingRate = samplingRate
    }
}
