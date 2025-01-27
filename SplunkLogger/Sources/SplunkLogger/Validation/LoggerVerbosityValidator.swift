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

/// Provides the implementer with a validation function to ensure logging allowance.
protocol LoggerVerbosityValidator: LoggerConfigurationProvider {

    /// Validates that the configured verbosity supports logging a message at the given `LogLevel` level.
    func shouldLog(at level: LogLevel) -> Bool
}


// MARK: - Validation

extension LoggerVerbosityValidator {

    /// Validates that the configured verbosity supports logging a message at the given `LogLevel` level.
    func shouldLog(at level: LogLevel) -> Bool {
        let verbosity: InternalLoggerVerbosity = configuration.verbosity

        guard
            verbosity != .silent,
            level.rawValue >= verbosity.rawValue
        else {
            return false
        }

        return true
    }
}
