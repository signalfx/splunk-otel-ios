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

/// The class implements default runtime attributes for the agent.
final class DefaultRuntimeAttributes: AgentRuntimeAttributes {

    // MARK: - Internal

    private unowned let owner: SplunkRum


    // MARK: - RuntimeAttributes protocol

    public var all: [String: Any] {
        var attributes: [String: Any] = [:]

        attributes["user.anonymous_id"] = userIdentifier()
        attributes["session.id"] = sessionIdentifier()

        return attributes
    }


    // MARK: - Initialization

    init(for owner: SplunkRum) {
        self.owner = owner
    }


    // MARK: - Private methods

    private func userIdentifier() -> String? {
        owner.user.identifier
    }

    private func sessionIdentifier() -> String? {
        owner.session.currentSessionId
    }
}
