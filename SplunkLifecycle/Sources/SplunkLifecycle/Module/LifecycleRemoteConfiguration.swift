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

/// Lifecycle remote configuration.
public struct LifecycleRemoteConfiguration: RemoteModuleConfiguration {

    // MARK: - Public

    /// Indicates whether the module should be enabled according to remote configuration.
    public var enabled: Bool = true


    // MARK: - Initialization

    /// Initializes a lifecycle remote configuration from JSON data.
    ///
    /// Topic 17 owns the remote-configuration contract, so this scaffold does
    /// not parse remote configuration yet.
    public init?(from _: Data) {
        nil
    }
}
