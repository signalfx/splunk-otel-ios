//
/*
Copyright 2026 Splunk Inc.

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

enum ErrorDiagnosticJSON {

    static func normalizeToJSONReady(_ value: Any, depth: Int = 0) -> Any {
        guard depth < 10 else {
            return value
        }

        if let dict = value as? [ErrorDiagnosticKeys: Any] {
            return Dictionary(
                uniqueKeysWithValues: dict.map {
                    ($0.key.rawValue, normalizeToJSONReady($0.value, depth: depth + 1))
                }
            )
        }

        if let array = value as? [[ErrorDiagnosticKeys: Any]] {
            return array.map { normalizeToJSONReady($0, depth: depth + 1) }
        }

        return value
    }

    static func convertToJSONString(_ item: Any) -> String? {
        guard
            let jsonData = try? JSONSerialization.data(
                withJSONObject: normalizeToJSONReady(item),
                options: .prettyPrinted
            )
        else {
            return nil
        }

        return String(data: jsonData, encoding: .utf8)
    }
}
