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

/// The class implements the Network Monitor module configuration.
@objc(SPLKNetworkMonitorConfiguration)
@objcMembers
public final class NetworkMonitorConfigurationObjC: ModuleConfigurationObjC {

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
}
