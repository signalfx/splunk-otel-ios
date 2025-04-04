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

/// Defines default values for configuration
struct ConfigurationDefaults {

    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    static var enableDebugLogging = false

    static var sessionSamplingRate = 1.0

    static var globalAttributes: [String: String] = [:]

    static var sessionTimeout = 15.0 * 60.0

    static var maxSessionLength = 4.0 * 60.0 * 60.0

    static var recordingEnabled = true
}
