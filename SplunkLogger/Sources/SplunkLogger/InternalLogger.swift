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
import OSLog

/// Manages the logging of interpolates string messages at their respective levels.
public final class InternalLogger: LoggerVerbosityValidator {

    // MARK: - Internal properties

    let configuration: InternalLoggerConfiguration


    // MARK: - Private properties

    private let logger: LoggerProvider
    private let loggingQueue: DispatchQueue


    // MARK: - Initialization

    /// Creates an `InternalLogger` instance.
    ///
    /// - Parameters:
    ///   - subsystem: `String`. Organizes large topic areas within the SDK.
    ///   - category: `String`. Within a `subsystem`, a category to further distinguish parts of the
    ///   subsystem.
    public init(configuration: InternalLoggerConfiguration) {
        if #available(iOS 14.0, tvOS 14.0, visionOS 1.0, macOS 11.0, *) {
            logger = ModernLogger(configuration: configuration)
        } else {
            logger = LegacyLogger(configuration: configuration)
        }

        self.configuration = configuration

        let loggerPrefix = LoggerPrefix.prefix(with: configuration.subsystem, and: configuration.category)
        loggingQueue = DispatchQueue(label: loggerPrefix, qos: .utility)
    }
}


// MARK: - Logging

public extension InternalLogger {

    /// Logs a string interpolation at the given level.
    ///
    /// Messages are logged asynchronously using a lower priority serial queue to avoid hiccups and delays in the SDK/app run.
    ///
    /// Depending on the target os version, either the `os_log` or the `Logger` API is used as the actual Logger.
    ///
    /// - Parameters:
    ///   - level: Specifies a `LogLevel` level to log the message at. Default is `.notice`.
    ///   - isPrivate: Sets the `OSLogPrivacy` attribute of the logging function.
    ///   - message: A block that returns the message `String` to be logged. The block is evalued only when the message is
    ///     actually published.
    func log(level: LogLevel = .notice, isPrivate: Bool = false, message: @escaping () -> String) {
        guard shouldLog(at: level) else {
            return
        }

        let constructedMessage = message()

        loggingQueue.async {
            self.logger.log(level: level, isPrivate: isPrivate, message: constructedMessage)
        }
    }
}
