//
/*
Copyright 2024 Splunk Inc.

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
import SplunkLogger

// MARK: Default configuration

public extension InternalLoggerConfiguration {

    /// Provides a default `InternalLoggerConfiguration` with the pre-specified subsystem to
    /// "SplunkAgent Crash Reporter" and a variable category.
    ///
    /// - Parameters:
    ///  - category: More finely-grained category of the logged subsystem.
    static func crashReporter(subsystem: String = "SplunkAgent Crash Reporter", category: String) -> InternalLoggerConfiguration {
        return InternalLoggerConfiguration(subsystem: subsystem, category: category)
    }
}
