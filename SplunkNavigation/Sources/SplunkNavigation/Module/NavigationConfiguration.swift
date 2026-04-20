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

    /// Indicates whether the Module is enabled.
    ///
    /// Default value is `true`.
    public var isEnabled: Bool = true

    /// A `Boolean` value determines whether the module should automatically detect navigation in the application.
    public var enableAutomatedTracking: Bool?

    /// Processor that intercepts automated navigation events before they produce spans.
    ///
    /// Set a custom ``NavigationEventProcessor`` to rename screens, add span attributes,
    /// or suppress specific navigation events. When `nil`, the default processor
    /// passes the sanitized controller type name through as the screen name.
    ///
    /// Manual ``Navigation/track(screen:)`` calls bypass the processor.
    public var navigationEventProcessor: (any NavigationEventProcessor)?


    // MARK: - Initialization

    /// Initialize a new configuration.
    public init() {}

    /// Initializes new module configuration with preconfigured values.
    ///
    /// - Parameters:
    ///   - isEnabled: A `Boolean` value sets whether the module is enabled.
    ///   - enableAutomatedTracking: If `true`, the module will automatically detect navigation.
    ///   - navigationEventProcessor: Optional processor to transform automated navigation events.
    public init(
        isEnabled: Bool,
        enableAutomatedTracking: Bool? = nil,
        navigationEventProcessor: (any NavigationEventProcessor)? = nil
    ) {
        self.isEnabled = isEnabled
        self.enableAutomatedTracking = enableAutomatedTracking
        self.navigationEventProcessor = navigationEventProcessor
    }


    // MARK: - Codable

    /// Non-serializable properties are excluded from serialization.
    enum CodingKeys: String, CodingKey {
        case isEnabled
        case enableAutomatedTracking
    }
}
