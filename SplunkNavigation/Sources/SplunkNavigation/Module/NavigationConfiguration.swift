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

import SplunkCommon

/// Navigation module configuration, minimal configuration for module conformance.
public struct NavigationConfiguration: ModuleConfiguration {

    // MARK: - Module management

    /// Indicates whether the Module is enabled. Default value is `true`.
    public var isEnabled: Bool = true

    /// A `Boolean` value determines whether the module should automatically detect navigation in the application.
    public var enableAutomatedTracking: Bool?


    // MARK: - Initialization

    /// Initialize a new configuration.
    public init() {}

    /// Initializes new module configuration with preconfigured values.
    ///
    /// - Parameters:
    ///   - isEnabled: A `Boolean` value sets whether the module is enabled.
    ///   - enableAutomatedTracking: If `true`, the module will automatically detect navigation.
    public init(isEnabled: Bool, enableAutomatedTracking: Bool? = nil) {
        self.isEnabled = isEnabled
        self.enableAutomatedTracking = enableAutomatedTracking
    }
}
