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

import OSLog

/// A logger implementation using the legacy `os_log` logging function.
struct LegacyLogger: LoggerProvider, LoggerVerbosityValidator {

    // MARK: - Internal properties

    let configuration: InternalLoggerConfiguration


    // MARK: - Private properties

    private var logger: OSLog


    // MARK: - Initialization

    init(configuration: InternalLoggerConfiguration) {
        self.configuration = configuration

        let category = configuration.category
        let subsystem = configuration.subsystem

        let loggerPrefix = LoggerPrefix.prefix(with: subsystem)

        logger = OSLog(subsystem: loggerPrefix, category: category)
    }


    // MARK: - Logging

    /// Logs given message using the legacy `os_log` API.
    func log(level: LogLevel, isPrivate: Bool, message: String) {
        let logType = level.logType

        if isPrivate {
            os_log("<private>", log: logger, type: logType)
        } else {
            os_log("%s", log: logger, type: logType, message)
        }
    }
}
