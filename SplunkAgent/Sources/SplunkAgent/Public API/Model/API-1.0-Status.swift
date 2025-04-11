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

/// A status of agent instance.
///
/// Describes the possible states for agent in which can be during its lifecycle.
public enum Status: Equatable {

    /// Recording is in progress.
    case running

    /// Recording is not in progress. A ``Cause`` determines the reason for this status.
    case notRunning(Cause)


    /// The cause why the recording is currently not running.
    public enum Cause {

        /// The agent has not been installed.
        case notInstalled

        /// The agent is not supported on the current platform.
        case unsupportedPlatform

        /// The agent is not running because of being sampled out locally.
        case sampledOut
    }
}


extension Status.Cause: CustomStringConvertible, CustomDebugStringConvertible {

    // MARK: - StringConvertible methods

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
