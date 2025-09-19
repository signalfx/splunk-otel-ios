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
import SplunkCommon

/// Describes a destination into which the `SlowFrameDetector` module sends its results.
///
/// This protocol defines the contract for sending slow and frozen frame data to a backend.
protocol SlowFrameDetectorDestination {

    /// Sends frame count results to a destination.
    ///
    /// - Parameters:
    ///   - type: The type of event being sent (e.g., "slowRenders", "frozenRenders").
    ///   - count: The number of events of that type that were detected.
    ///   - sharedState: The shared state of the agent, providing context like the agent version.
    func send(type: String, count: Int, sharedState: AgentSharedState?) async
}
