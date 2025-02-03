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

// MARK: - Default configuration

public extension InternalLoggerConfiguration {

    /// Provides a default `InternalLoggerConfiguration` with the specified subsystem.
    /// - Parameter subsystem: Organizes large topic areas within the SDK.
    static func `default`(subsystem: String) -> InternalLoggerConfiguration {
        return InternalLoggerConfiguration(subsystem: subsystem)
    }


    /// Provides a default `InternalLoggerConfiguration` with the specified subsystem and category.
    /// - Parameters:
    ///  - subsystem: Organizes large topic areas within the SDK.
    ///  - category: More finely-grained category of the logged subsystem.
    static func `default`(subsystem: String, category: String) -> InternalLoggerConfiguration {
        return InternalLoggerConfiguration(subsystem: subsystem, category: category)
    }


    /// Provides a default `InternalLoggerConfiguration` with the pre-specified subsystem to "Splunk RUM Agent" and a variable category.
    /// - Parameters:
    ///  - category: More finely-grained category of the logged subsystem.
    static func agent(subsystem: String = "Splunk RUM Agent", category: String) -> InternalLoggerConfiguration {
        return InternalLoggerConfiguration(subsystem: subsystem, category: category)
    }
}
