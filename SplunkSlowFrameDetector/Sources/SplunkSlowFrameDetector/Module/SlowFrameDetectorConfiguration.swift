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

/// SlowFrameDetector module configuration, minimal configuration for module conformance.
public struct SlowFrameDetectorConfiguration: ModuleConfiguration {

    /// Indicates whether the Module is enabled.
    ///
    /// Default value is `true`.
    public var isEnabled: Bool = true

    /// Initialize a new configuration.
    public init() {}

    /// Initializes new module configuration using value provided for isEnabled.
    ///
    /// - Parameter isEnabled: A `Boolean` value sets whether the module is enabled.
    public init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }
}
