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

/// Base class for implementing module configurations.
///
/// - Warning: Not intended for direct use by SDK users.
@objc(SPLKModuleConfiguration)
@objcMembers
public class ModuleConfigurationObjC: NSObject {

    // MARK: - Module management

    /// Indicates whether the Module is enabled. Default value is `YES`.
    public var isEnabled: Bool = true


    // MARK: - Initialization

    // Initialization is hidden from the public API
    // as we only need to work with the descendant types.
    override init() {}
}
