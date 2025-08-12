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

/// Defines a read-only view of the agent's current state and key configuration details.
protocol AgentState {

    // MARK: - Agent status

    /// The current operational status of the agent, represented by a ``Status`` value.
    var status: Status { get }


    // MARK: - Current Configuration

    /// The configuration for the agent's communication endpoint, represented by an ``EndpointConfiguration`` object.
    var endpointConfiguration: EndpointConfiguration { get }

    /// The name of the application being monitored.
    var appName: String { get }

    /// The version of the application being monitored.
    var appVersion: String { get }
}
