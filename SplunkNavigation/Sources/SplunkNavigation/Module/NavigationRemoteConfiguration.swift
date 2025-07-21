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

/// Navigation module remote configuration.
public struct NavigationRemoteConfiguration: RemoteModuleConfiguration {

    // MARK: - Module management

    /// A boolean value that indicates whether the module is enabled through remote settings. Defaults to `true`.
    public var enabled: Bool = true


    // MARK: - Initialization

    /// Initializes the remote configuration from a `Data` object.
    ///
    /// - Note: This initializer is a placeholder and does not parse the provided data, as remote configuration is not yet fully implemented for this module.
    /// - Parameter data: The remote configuration data. This parameter is ignored.
    public init?(from data: Data) {}
}
