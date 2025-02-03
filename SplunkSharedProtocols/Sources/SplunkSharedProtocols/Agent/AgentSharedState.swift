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

import Foundation

/// Internal protocol for sharing agent state with modules.
///
/// The Agent uses the protocol internally to manage Modules and their Events.
public protocol AgentSharedState: AnyObject {

    // MARK: - General state

    /// Identification of the current session at the time of the creation of this state.
    var sessionId: String { get }

    /// Returns application state for the given timestamp.
    func applicationState(for timestamp: Date) -> String?
}
