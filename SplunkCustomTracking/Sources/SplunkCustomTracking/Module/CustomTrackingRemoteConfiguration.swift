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
import SplunkCommon

// Minimal protocol conformance.
/// Decodes and stores remote configuration settings for the Custom Tracking module.
///
/// This structure conforms to `RemoteModuleConfiguration` and is responsible for parsing
/// a `Data` object (typically JSON) to determine if the custom tracking feature should be enabled.
public struct CustomTrackingRemoteConfiguration: RemoteModuleConfiguration {


    // MARK: - Internal decoding

    struct CustomTracking: Decodable {
        let enabled: Bool
    }

    struct MRUMRoot: Decodable {
        let customTracking: CustomTracking
    }

    struct Configuration: Decodable {
        let mrum: MRUMRoot
    }

    struct Root: Decodable {
        let configuration: Configuration
    }


    // MARK: - Protocol compliance

    /// A boolean flag indicating whether the Custom Tracking module is enabled according to the remote configuration.
    /// Defaults to `true`.
    public var enabled: Bool = true

    /// Failable initializer that decodes the remote configuration from a `Data` object.
    ///
    /// This initializer attempts to parse a specific JSON structure to find the `enabled` flag for custom tracking.
    /// If the `Data` cannot be decoded into the expected format, the initializer returns `nil`.
    ///
    /// - Parameter data: The `Data` object containing the remote configuration settings.
    public init?(from data: Data) {
        guard let root = try? JSONDecoder().decode(Root.self, from: data) else {
            return nil
        }

        enabled = root.configuration.mrum.customTracking.enabled
    }
}
