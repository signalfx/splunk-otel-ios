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

/// Interactions remote configuration, minimal configuration for module conformance.
public struct InteractionsRemoteConfiguration: RemoteModuleConfiguration {

    // MARK: - Protocol compliance

    /// A boolean value that indicates whether the module is enabled.
    ///
    /// The default value is `true`.
    public var enabled: Bool = true

    /// Initializes the remote configuration from a `Data` object.
    ///
    /// This initializer is required for `RemoteModuleConfiguration` conformance but is not implemented for interactions, as remote configuration is not supported for this module.
    /// It will always result in a `nil` instance.
    /// - Parameter data: The data to decode the configuration from. This parameter is ignored.
    public init?(from data: Data) {}
}
