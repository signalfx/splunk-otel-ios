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

/// Provides information about customer's application.
struct AppInfo {

    // MARK: - Application information

    static let name = Bundle.main.infoDictionary?["CFBundleName"] as? String
    static let bundleId = Bundle.main.bundleIdentifier
    static let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    static let buildId = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
}
