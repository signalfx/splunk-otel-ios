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

#if os(iOS) || os(tvOS) || os(visionOS)
    import UIKit
#endif

/// Provides information about the operating system.
struct SystemInfo {

    // MARK: - Operating system

    static var name: String {
        #if os(iOS) || os(tvOS) || os(visionOS)
            return UIDevice.current.systemName

        #elseif os(macOS)
            return"macOS"
        #endif
    }

    static var version: String? {
        var osVersion: String?

        #if os(iOS) || os(tvOS) || os(visionOS)
            osVersion = UIDevice.current.systemVersion

        #elseif os(macOS)
            let major = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
            let minor = ProcessInfo.processInfo.operatingSystemVersion.minorVersion
            let patch = ProcessInfo.processInfo.operatingSystemVersion.patchVersion

            osVersion = String(format: "%ld.%ld.%ld", major, minor, patch)
        #endif

        return osVersion
    }

    static var description: String {
        let osName = name
        let osVersionString = ProcessInfo.processInfo.operatingSystemVersionString

        return "\(osName) \(osVersionString)"
    }

    static var type: String {
        return "darwin"
    }
}
