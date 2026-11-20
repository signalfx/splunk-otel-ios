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

/// Formats the `config_settings` attribute of the `SplunkRum.install` span.
@_spi(SplunkInternal)
public enum AgentInitializeFormatting {

    /// Returns the settings as `[key:value, key:value]`, or `nil` when there are none.
    public static func configurationSettings(_ settings: [String: String]) -> String? {
        if settings.isEmpty {
            return nil
        }

        var formatted = "["

        for (key, value) in settings {
            if formatted.count > 1 {
                formatted += ", "
            }

            formatted += "\(key):\(value)"
        }

        formatted += "]"

        return formatted
    }
}
