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

private enum SplunkDebugDateFormatter {

    private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static var localizationCache: (localeID: String, format: String)?

    static func iso8601String(from date: Date) -> String {
        dateFormatter.string(from: date)
    }

    static func localizedString(from date: Date) -> String {
        let locale = Locale.autoupdatingCurrent
        let format = formatForLocale(locale)

        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = TimeZone.autoupdatingCurrent
        formatter.dateFormat = format

        return formatter.string(from: date)
    }

    private static var dateFormatter: ISO8601DateFormatter {
        iso8601
    }

    private static func formatForLocale(_ locale: Locale) -> String {

        if let cached = localizationCache, cached.localeID == locale.identifier {
            return cached.format
        }

        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = TimeZone.autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("yMMMdjmszzzz")

        var format = formatter.dateFormat ?? "yyyy-MM-dd HH:mm:ss zzz"

        if !format.contains("ss.SSS") {
            if let secondsRange = format.range(of: "ss") {
                format.replaceSubrange(secondsRange, with: "ss.SSS")
            }
            else {
                let separator = format.hasSuffix(" ") ? "" : " "
                format += "\(separator)ss.SSS"
            }
        }

        localizationCache = (locale.identifier, format)
        return format
    }
}

extension Date {
    /// Returns a string representation of the date in ISO 8601 format with milliseconds, always in UTC.
    func iso8601Formatted() -> String {
        SplunkDebugDateFormatter.iso8601String(from: self)
    }

    /// Returns a localized string representation for debug logs, ensuring milliseconds are visible.
    func localizedDebugFormatted() -> String {
        SplunkDebugDateFormatter.localizedString(from: self)
    }
}
