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

/// Utilities for deriving user-facing class names from UIKit instrumentation type names.
public enum ClassNameSanitization {

    // MARK: - Public

    /// Returns the bundle name for the guest application.
    public static func applicationBundleName() -> String? {
        Bundle.main.object(forInfoDictionaryKey: kCFBundleNameKey as String) as? String
    }

    /// Drops the host application bundle prefix from a type name.
    public static func sanitize(typeName: String, bundleName: String?) -> String {
        guard
            let bundleName,
            typeName.hasPrefix(bundleName)
        else {
            return typeName
        }

        return String(typeName.dropFirst("\(bundleName).".count))
    }
}
