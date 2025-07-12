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

/// An enumeration that represents the lifecycle status of the agent.
///
/// You can check this status to understand whether the agent is actively recording and sending data.
///
/// ### Example ###
/// ```
/// switch SplunkRum.shared.state.status {
/// case .running:
///     print("Agent is running.")
/// case .notRunning(let cause):
///     print("Agent is not running due to: \(cause)")
/// }
/// ```
public enum Status: Equatable {

    /// The agent is actively recording and sending telemetry data.
    case running

    /// The agent is not recording. The associated `Cause` value provides the specific reason.
    case notRunning(Cause)


    /// The reason why the agent's status is `.notRunning`.
    public enum Cause {

        /// The agent has not been installed via `SplunkRum.install`.
        case notInstalled

        /// The agent does not support the current operating system or platform.
        case unsupportedPlatform

        /// The agent is not running for this session because it has been sampled out
        /// based on the configured sampling rate.
        case sampledOut
    }
}


extension Status.Cause: CustomStringConvertible, CustomDebugStringConvertible {

    // MARK: - StringConvertible methods

    /// A human-readable description of the cause.
    public var description: String {
        switch self {
        case .notInstalled:
            return "The agent has not been installed."

        case .unsupportedPlatform:
            return "The agent is not supported on the current platform."

        case .sampledOut:
            return "The agent is not running because of being sampled out locally."
        }
    }

    public var debugDescription: String {
        return description
    }
}