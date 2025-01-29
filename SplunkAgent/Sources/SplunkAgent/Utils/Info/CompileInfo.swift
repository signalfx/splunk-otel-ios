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

/// Provides information about the operating system at the compile time.
struct CompileInfo {

    // MARK: - Inline types

    /// A compile-time target platform.
    enum Platform: String, Codable {
        case unknown
        case macOS
        case macCatalyst
        case iOS
        case watchOS
        case tvOS
        case visionOS
    }


    // MARK: - Compile platform

    /// The target platform for which the currently running code has been compiled.
    static var platform: Platform {
        #if os(macOS)
            return .macOS

        #elseif targetEnvironment(macCatalyst)
            return .macCatalyst

        #elseif os(iOS)
            return .iOS

        #elseif os(watchOS)
            return .watchOS

        #elseif os(tvOS)
            return .tvOS

        #elseif os(visionOS)
            return .visionOS

        #else
            return .unknown
        #endif
    }
}
