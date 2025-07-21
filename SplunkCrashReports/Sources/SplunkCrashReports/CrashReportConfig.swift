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

/// Crash reports module configuration, minimal configuration for module conformance.
public struct CrashReportsConfiguration: ModuleConfiguration {

    // MARK: - Module management

    /// Indicates whether the Module is enabled. Default value is `true`.
    public var isEnabled: Bool = true

    /// Initializes new module configuration with preconfigured values.
    ///
    /// - Parameters:
    ///   - isEnabled: A `Boolean` value sets whether the module is enabled.
    public init(isEnabled: Bool) {
        self.isEnabled = isEnabled
    }
}

/// A structure that represents the remote configuration for the Crash Reports module.
///
/// This configuration is typically fetched from a remote server and allows for dynamic control
/// over the module's behavior.
public struct CrashReportsRemoteConfiguration: RemoteModuleConfiguration {

    // MARK: - Internal decoding

    struct CrashReporting: Decodable {
        let enabled: Bool
    }

    struct MRUMRoot: Decodable {
        let crashReporting: CrashReporting
    }

    struct Configuration: Decodable {
        let mrum: MRUMRoot
    }

    struct Root: Decodable {
        let configuration: Configuration
    }

    // MARK: - Protocol compliance

    /// A Boolean value that indicates whether the Crash Reports module is enabled or disabled through remote configuration.
    public var enabled: Bool

    /// Initializes the remote configuration from a `Data` object, typically received from a remote source.
    ///
    /// This initializer decodes the JSON data to configure the Crash Reports module's `enabled` state.
    /// - Note: The initializer will fail and return `nil` if the provided data cannot be decoded into the expected format.
    /// - Parameter data: The `Data` object containing the JSON configuration.
    public init?(from data: Data) {
        guard let root = try? JSONDecoder().decode(Root.self, from: data) else {
            return nil
        }

        enabled = root.configuration.mrum.crashReporting.enabled
    }
}
