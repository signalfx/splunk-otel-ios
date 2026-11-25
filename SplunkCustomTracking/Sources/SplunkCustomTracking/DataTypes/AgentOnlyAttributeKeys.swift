//
/*
Copyright 2026 Splunk Inc.

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

/// Keys of the session attributes that only the agent sets on custom events, errors and workflow
/// spans.
///
/// A value the app supplies under one of these keys is ignored. A custom event or error takes the
/// session that is current when it is published, and a workflow span the session current when it
/// started; with no session, the signal is dropped.
enum AgentOnlyAttributeKeys {
    static let all = SessionAttributeKeys.agentOnly
}

extension Dictionary where Key == String {

    /// The attributes without those only the agent sets.
    func removingAgentOnlyAttributes() -> Self {
        var attributes = self

        for key in AgentOnlyAttributeKeys.all {
            attributes.removeValue(forKey: key)
        }

        return attributes
    }
}
