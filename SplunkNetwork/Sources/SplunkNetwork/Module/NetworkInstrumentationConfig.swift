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

/// Network Instrumentation module configuration.
public struct NetworkInstrumentationConfiguration: ModuleConfiguration {

    // MARK: - Public

    /// Indicates whether the Module is enabled. Default value is `true`.
    public var isEnabled: Bool = true

    /// Describes URLs to be ignored by the module when reporting on network activity.
    public var ignoreURLs: IgnoreURLs

    // MARK: init()

    /// Initializes new module configuration with preconfigured values.
    ///
    /// - Parameters:
    ///   - isEnabled: A `Boolean` value sets whether the module is enabled.
    ///   - ignoreURLs: If present, the module will not report on these URLs.
    public init(isEnabled: Bool, ignoreURLs: IgnoreURLs) {
        self.isEnabled = isEnabled
        self.ignoreURLs = ignoreURLs
    }
}

/// Network Instrumentation module remote configuration.
public struct NetworkInstrumentationRemoteConfig: RemoteModuleConfiguration {

    // MARK: - Internal decoding

    struct NetworkTracing: Decodable {
        let enabled: Bool
        let ignoreURLs: IgnoreURLs
    }

    struct MRUMRoot: Decodable {
        let networkTracing: NetworkTracing
    }

    struct Configuration: Decodable {
        let mrum: MRUMRoot
    }

    struct Root: Decodable {
        let configuration: Configuration
    }

    // MARK: - Protocol compliance

    public var enabled: Bool
    public var ignoreURLs: IgnoreURLs

    public init?(from data: Data) {
        guard let root = try? JSONDecoder().decode(Root.self, from: data) else {
            return nil
        }

        enabled = root.configuration.mrum.networkTracing.enabled
        ignoreURLs = root.configuration.mrum.networkTracing.ignoreURLs
    }
}
