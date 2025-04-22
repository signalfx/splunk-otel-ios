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

internal import SplunkSharedProtocols

/// Defines runtime attributes in the agent space.
protocol AgentRuntimeAttributes: RuntimeAttributes {

    // MARK: - Custom attributes

    /// A list of custom attributes to use at signal start.
    var custom: [String: Any] { get }


    // MARK: - Custom attributes management

    /// Update or add a new custom attribute. This method is thread-safe.
    ///
    /// - Parameters:
    ///   - named: A `String` with the name of the attribute.
    ///   - value: The new value of the attribute.
    func updateCustom(named: String, with value: Any)

    /// Remove custom attribute. This method is thread-safe.
    ///
    /// - Parameter named: A `String` with the name of the removed attribute.
    func removeCustom(named: String)
}
