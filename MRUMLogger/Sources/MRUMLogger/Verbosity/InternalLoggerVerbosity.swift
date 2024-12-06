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

/// Logger verbosity levels.
public enum InternalLoggerVerbosity: Int {

    /// No messages are logged.
    case silent = 0

    /// Logs messages at all `MRUMLogLevel` levels.
    case verbose = 1

    /// Logs all `notice`, `warn`, `error`, and `fault` messages.
    ///
    /// Used as a `default` value.
    case standard = 3
}

// MARK: - Default verbosity

public extension InternalLoggerVerbosity {

    /// The default logger verbosity level.
    static let `default` = InternalLoggerVerbosity.standard
}
