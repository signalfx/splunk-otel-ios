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

public import SplunkCommon

/// Configuration for the navigation module.
///
/// Use this type to enable automated navigation tracking and optionally
/// configure a ``NavigationModuleEventProcessor`` to customize screen names,
/// add span attributes, or suppress specific navigation events.
///
/// Pass an instance in the `moduleConfigurations` array when installing the agent:
///
/// ```swift
/// let navConfig = NavigationConfiguration(
///     enableAutomatedTracking: true,
///     navigationEventProcessor: MyProcessor()
/// )
/// try SplunkRum.install(with: config, moduleConfigurations: [navConfig])
/// ```
public struct NavigationConfiguration: ModuleConfiguration {

    // MARK: - Module management

    /// Indicates whether the module is enabled.
    ///
    /// Default value is `true`.
    public var isEnabled: Bool = true

    /// A `Boolean` value determines whether the module should automatically detect navigation in the application.
    public var enableAutomatedTracking: Bool?

    /// Processor that intercepts automated navigation events before they produce spans.
    ///
    /// Set a custom ``NavigationModuleEventProcessor`` to rename screens, add span attributes,
    /// or suppress specific navigation events. When `nil`, the default processor
    /// passes the sanitized controller type name through as the screen name.
    ///
    /// Manual ``NavigationModule/track(screen:)`` calls bypass the processor.
    ///
    /// - Important: The processor is retained strongly by the SDK for the lifetime
    ///   of the agent. Avoid capturing references that transitively own `SplunkRum`;
    ///   prefer stateless processors or weak captures where needed.
    public var navigationEventProcessor: (any NavigationModuleEventProcessor)?


    // MARK: - Initialization

    /// Initializes new module configuration with default values.
    public init() {}

    /// Initializes new module configuration with preconfigured values.
    ///
    /// - Parameters:
    ///   - isEnabled: A `Boolean` value sets whether the module is enabled.
    ///   - enableAutomatedTracking: If `true`, the module will automatically detect navigation.
    ///   - navigationEventProcessor: Optional processor to transform automated navigation events.
    public init(
        isEnabled: Bool = true,
        enableAutomatedTracking: Bool? = nil,
        navigationEventProcessor: (any NavigationModuleEventProcessor)? = nil
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
