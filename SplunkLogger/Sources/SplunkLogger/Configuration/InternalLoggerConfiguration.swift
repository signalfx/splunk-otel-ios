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

/// Logger configuration object.
public struct InternalLoggerConfiguration {

    // MARK: - Public properties

    /// Defines the logger's preferred `InternalLoggerVerbosity` verbosity level.
    ///
    /// If no verbosity is provided, `.verbose` level is used.
    public let verbosity: InternalLoggerVerbosity

    /// Organizes large topic areas within the SDK.
    public let subsystem: String

    /// More finely-grained category of the logged subsystem.
    ///
    /// If no category is provided, `.default` value is used.
    public let category: String


    // MARK: - Initialization

    public init(verbosity: InternalLoggerVerbosity = .default, subsystem: String, category: String = "default") {
        self.verbosity = verbosity
        self.subsystem = subsystem
        self.category = category
    }
}
