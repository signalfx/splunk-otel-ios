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

/// The configuration for the `SlowFrameDetector` module.
public struct SlowFrameDetectorConfiguration: ModuleConfiguration {

<<<<<<< HEAD
    // MARK: - Public

    /// A boolean value indicating whether the `SlowFrameDetector` module is enabled.
    /// The default value is `true`.
=======
    /// Indicates whether the Module is enabled.
    ///
    /// Default value is `true`.
>>>>>>> origin/develop
    public var isEnabled: Bool = true

    // MARK: - Initialization

    /// Initializes a new configuration with default values.
    public init() {}

    /// Initializes a new module configuration.
    ///
<<<<<<< HEAD
    /// - Parameters:
    ///   - isEnabled: A `Boolean` value that sets whether the module is enabled. The default is `true`.
=======
    /// - Parameter isEnabled: A `Boolean` value sets whether the module is enabled.
>>>>>>> origin/develop
    public init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }
}
