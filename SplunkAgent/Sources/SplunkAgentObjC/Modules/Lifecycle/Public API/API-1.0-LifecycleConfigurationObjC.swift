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

/// Objective-C configuration for the lifecycle module.
///
/// Supported action strings are `view_created`, `resumed`, and `stopped`.
/// Android lifecycle action strings not supported by iOS are silently ignored
/// when this configuration is converted to Swift.
@objc(SPLKLifecycleConfiguration)
@objcMembers
public final class LifecycleConfigurationObjC: ModuleConfigurationObjC {

    // MARK: - Module management

    /// Lifecycle action strings that should emit telemetry.
    public var allowedEvents: [String] = LifecycleActionObjC.defaultAllowedEvents


    // MARK: - Initialization

    /// Initializes new module configuration.
    override public init() {
        super.init()
    }

    /// Initializes new module configuration with preconfigured values.
    ///
    /// - Parameter isEnabled: A `BOOL` value sets whether the module is enabled.
    @objc(initWithEnabled:)
    public init(isEnabled: Bool) {
        super.init()

        self.isEnabled = isEnabled
    }

    /// Initializes new module configuration with preconfigured values.
    ///
    /// - Parameter allowedEvents: Lifecycle action strings that should emit telemetry.
    @objc(initWithAllowedEvents:)
    public convenience init(allowedEvents: [String]) {
        self.init(isEnabled: true, allowedEvents: allowedEvents)
    }

    /// Initializes new module configuration with preconfigured values.
    ///
    /// - Parameters:
    ///   - isEnabled: A `BOOL` value sets whether the module is enabled.
    ///   - allowedEvents: Lifecycle action strings that should emit telemetry.
    @objc(initWithEnabled:allowedEvents:)
    public init(isEnabled: Bool, allowedEvents: [String]) {
        super.init()

        self.isEnabled = isEnabled
        self.allowedEvents = allowedEvents
    }
}
