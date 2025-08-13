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

extension AgentConfigurationProtocol {

    /// Merges remote configuration settings into the current configuration.
    ///
    /// This method updates properties such as `sessionTimeout` and `maxSessionLength`
    /// with values fetched from a remote source. If the remote configuration is `nil`,
    /// no changes are made.
    ///
    /// - Parameter remote: An optional ``RemoteConfiguration`` object containing the settings to merge.
    mutating func mergeRemote(_ remote: RemoteConfiguration?) {
        guard let remote else {
            return
        }

        sessionTimeout = remote.configuration.mrum.sessionTimeout
        maxSessionLength = remote.configuration.mrum.maxSessionLength
    }
}
