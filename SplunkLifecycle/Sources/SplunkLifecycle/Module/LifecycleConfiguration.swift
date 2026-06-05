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

import SplunkCommon

/// Lifecycle module configuration.
public struct LifecycleConfiguration: ModuleConfiguration {

    // MARK: - Public

    /// Indicates whether the module is enabled.
    ///
    /// Default value is `true`.
    public var isEnabled: Bool

    /// Lifecycle actions that should emit telemetry.
    public var allowedEvents: Set<LifecycleAction>


    // MARK: - Initialization

    /// Initializes a lifecycle configuration with preconfigured values.
    ///
    /// - Parameters:
    ///   - isEnabled: A Boolean value that sets whether the module is enabled.
    ///   - allowedEvents: Lifecycle actions that should emit telemetry.
    public init(
        isEnabled: Bool = true,
        allowedEvents: Set<LifecycleAction> = LifecycleAction.mainLifecycleEvents
    ) {
        self.isEnabled = isEnabled
        self.allowedEvents = allowedEvents
    }
}
