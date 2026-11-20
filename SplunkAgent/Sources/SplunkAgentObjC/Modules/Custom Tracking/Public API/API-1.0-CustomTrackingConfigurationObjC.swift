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

/// The class implements the Custom Tracking module configuration.
@objc(SPLKCustomTrackingConfiguration)
@objcMembers
public final class CustomTrackingConfigurationObjC: ModuleConfigurationObjC {

    // MARK: - Error diagnostics

    /// Indicates whether tracked errors and exceptions may include binary image metadata.
    ///
    /// Default value is `YES`.
    public var includeBinaryImagesOnErrors = true


    // MARK: - Initialization

    /// Initializes new module configuration.
    override public init() {
        super.init()
    }

    /// Initializes new module configuration with preconfigured values.
    ///
    /// - Parameters:
    ///   - isEnabled: A `BOOL` value sets whether the module is enabled.
    ///   - includeBinaryImagesOnErrors: A `BOOL` value sets whether tracked errors and exceptions may include binary image metadata.
    @objc(initWithEnabled:includeBinaryImagesOnErrors:)
    public init(isEnabled: Bool, includeBinaryImagesOnErrors: Bool) {
        super.init()

        self.isEnabled = isEnabled
        self.includeBinaryImagesOnErrors = includeBinaryImagesOnErrors
    }
}
