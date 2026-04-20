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
import SplunkNavigation

/// Objective-C configuration for the navigation module.
///
/// Use this class to enable automated navigation tracking and optionally
/// configure a ``NavigationEventProcessor`` to customize screen names,
/// add span attributes, or suppress specific navigation events.
@objc(SPLKNavigationConfiguration)
@objcMembers
public final class NavigationConfigurationObjC: ModuleConfigurationObjC {

    // MARK: - Module management

    /// A `BOOL` value determines whether the module should automatically detect navigation in the application.
    ///
    /// Default value is `NO`.
    public var enableAutomatedTracking: Bool = false

    /// Processor that intercepts automated navigation events before they produce spans.
    ///
    /// Set a custom ``NavigationEventProcessor`` to rename screens, add span attributes,
    /// or suppress specific events by returning `nil` from the processor method.
    /// When `nil`, the default processor passes the controller type name through unchanged.
    public var navigationEventProcessor: NavigationEventProcessor?


    // MARK: - Initialization

    /// Initializes new module configuration.
    override public init() {
        super.init()
    }

    /// Initializes new module configuration with preconfigured values.
    ///
    /// - Parameter isEnabled: A `BOOL` value sets whether the module is enabled.
    @objc(initWithEnabled:)
    public convenience init(isEnabled: Bool) {
        self.init(isEnabled: isEnabled, enableAutomatedTracking: false)
    }

    /// Initializes new module configuration with preconfigured values.
    ///
    /// - Parameters:
    ///   - isEnabled: A `BOOL` value sets whether the module is enabled.
    ///   - enableAutomatedTracking: If `YES`, the module will automatically detect navigation.
    @objc(initWithEnabled:automatedTracking:)
    public init(isEnabled: Bool, enableAutomatedTracking: Bool) {
        super.init()

        self.isEnabled = isEnabled
        self.enableAutomatedTracking = enableAutomatedTracking
    }

    /// Initializes new module configuration with preconfigured values.
    ///
    /// - Parameters:
    ///   - isEnabled: A `BOOL` value sets whether the module is enabled.
    ///   - enableAutomatedTracking: If `YES`, the module will automatically detect navigation.
    ///   - navigationEventProcessor: Optional processor to transform automated navigation events.
    @objc(initWithEnabled:automatedTracking:navigationEventProcessor:)
    public init(
        isEnabled: Bool,
        enableAutomatedTracking: Bool,
        navigationEventProcessor: NavigationEventProcessor?
    ) {
        super.init()

        self.isEnabled = isEnabled
        self.enableAutomatedTracking = enableAutomatedTracking
        self.navigationEventProcessor = navigationEventProcessor
    }
}
