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

/// Custom tracking module configuration.
public struct CustomTrackingConfiguration: ModuleConfiguration {

    // MARK: - Public

    /// Indicates whether the Module is enabled.
    ///
    /// Default value is `true`.
    public var isEnabled: Bool = true

    /// When enabled, `trackError` and `trackException` may attach stack-referenced `exception.images`
    /// metadata from a PLCrashReporter live report, matching the crash report payload shape.
    ///
    /// String-only errors are not enriched. Platforms without PLCrashReporter support omit the attribute.
    /// Default is `true`.
    public var includeBinaryImagesOnErrors: Bool = true

    // MARK: - Initialization

    public init(
        isEnabled: Bool = true,
        includeBinaryImagesOnErrors: Bool = true
    ) {
        self.isEnabled = isEnabled
        self.includeBinaryImagesOnErrors = includeBinaryImagesOnErrors
    }
}
