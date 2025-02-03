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

/// Implements the logger prefix string for the respective `InternalLogger` loggers.
struct LoggerPrefix {

    // MARK: - Static logger prefix

    static let `default`: String = "com.splunk.rum"


    // MARK: - Logger prefix

    static func prefix(with subsystem: String) -> String {
        return "\(`default`).\(subsystem)"
    }

    static func prefix(with subsystem: String, and category: String) -> String {
        return "\(`default`).\(subsystem).\(category)"
    }
}
