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

import Foundation

/// A private enum to hold the lazily-initialized legacy date formatter.
/// This is a performant pattern that avoids re-creating the formatter on every call.
private enum SplunkLegacyDateFormatter {
    static let iso8601: DateFormatter = {
        let formatter = DateFormatter()
        // Using a standard, locale-independent format is crucial for logs.
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}

extension Date {
    /// Returns a string representation of the date formatted for Splunk logs.
    /// This method is backward-compatible with iOS versions prior to 15.
    func splunkFormatted() -> String {
        guard #available(iOS 15.0, *) else {
            // Use the legacy DateFormatter for older OS versions.
            return SplunkLegacyDateFormatter.iso8601.string(from: self)
        }

        // Use the modern, efficient API on iOS 15 and newer.
        return formatted(.iso8601)
    }
}
