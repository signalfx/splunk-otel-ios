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

/// Supported log levels. Used for capturing information.
public enum LogLevel: Int {

    /// Verbose information during development that is useful only for debugging.
    case debug = 1

    /// Information that is helpful, but not essential, to troubleshoot issues.
    case info = 2

    /// Information that is essential for the SDK and for the troubleshooting of issues.
    ///
    /// Used as the `default` log level.
    case notice = 3

    /// Information that might result in a failure.
    ///
    /// If an activity object exists, the system captures information for the related process chain.
    case warn = 5

    /// Errorneous information seen during the execution of the code.
    ///
    /// If an activity object exists, the system captures information for the related process chain.
    case error = 6

    /// Information about faults and bugs in your code.
    ///
    /// If an activity object exists, the system captures information for the related process chain.
    case fault = 7
}
