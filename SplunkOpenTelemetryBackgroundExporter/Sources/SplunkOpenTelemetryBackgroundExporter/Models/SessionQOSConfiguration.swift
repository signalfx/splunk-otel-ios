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

/// A configuration object that defines the Quality of Service (QOS) settings for background network sessions.
///
/// These settings control how the system handles network tasks based on the current network conditions.
public struct SessionQOSConfiguration {

    // MARK: - Public

    /// A Boolean value indicating whether to allow network access over cellular connections.
    public let allowsCellularAccess: Bool

    /// A Boolean value indicating whether to allow network access over constrained networks, such as Low Data Mode.
    public let allowsConstrainedNetworkAccess: Bool

    /// A Boolean value indicating whether to allow network access over networks considered expensive by the system (e.g., personal hotspots).
    public let allowsExpensiveNetworkAccess: Bool


    // MARK: - Initialization

    /// Initializes the QOS configuration with specific network access settings.
    /// - Parameters:
    ///   - allowsCellularAccess: The setting for cellular network access. Defaults to `true`.
    ///   - allowsConstrainedNetworkAccess: The setting for constrained network access. Defaults to `true`.
    ///   - allowsExpensiveNetworkAccess: The setting for expensive network access. Defaults to `true`.
    public init(
        allowsCellularAccess: Bool = true,
        allowsConstrainedNetworkAccess: Bool = true,
        allowsExpensiveNetworkAccess: Bool = true
    ) {
        self.allowsCellularAccess = allowsCellularAccess
        self.allowsConstrainedNetworkAccess = allowsConstrainedNetworkAccess
        self.allowsExpensiveNetworkAccess = allowsExpensiveNetworkAccess
    }
}
