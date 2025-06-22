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

public extension SplunkRum {

    /// Identification of recorded session.
    ///
    /// When the agent is initialized, there is always some session ID.
    @available(*, deprecated, message: "This function will be removed in a later version. Use the new `SplunkRum` API instead.")
    static func getSessionId() -> String {
        SplunkRum.shared.session.state.id
    }
    
    /// A boolean determinning the `Status` of agent recording.
    ///
    /// - Returns: True when the status resolves to `.running`.
    @available(*, deprecated, message: "This function will be removed in a later version. Use the new `SplunkRum` API instead.")
    static func isInitialized() -> Bool {
        SplunkRum.shared.state.status == .running
    }

    @available(*, deprecated, message: "This function will be removed in a later version.")
    static func debugLog(_ msg: String) { }
}
