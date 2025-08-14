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

// JSON Support for Crash Reports.

extension CrashReports {

    func normalizeToJSONReady(_ value: Any, depth: Int = 0) -> Any {
        // Runaway recursion check
        guard depth < 10 else {
            return value
        }

        if let dict = value as? [CrashReportKeys: Any] {
            return Dictionary(uniqueKeysWithValues: dict.map {
                ($0.key.rawValue, normalizeToJSONReady($0.value, depth: depth + 1))
            })
        } else if let array = value as? [[CrashReportKeys: Any]] {
            return array.map { normalizeToJSONReady($0, depth: depth + 1) }
        } else {
            return value
        }
    }

    func convertToJSONString(_ item: Any) -> String? {
        guard let jsonData = try? JSONSerialization.data(
            withJSONObject: normalizeToJSONReady(item),
            options: .prettyPrinted
        ) else {
            logger.log(level: .debug) {
                "Crash Report data could not be converted to JSON."
            }
            return nil
        }
        return String(data: jsonData, encoding: .utf8)
    }
}
