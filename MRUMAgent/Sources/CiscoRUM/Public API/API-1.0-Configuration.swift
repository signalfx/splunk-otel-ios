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

/// Structure that holds configuration for initial SDK setup.
///
/// Configuration is always bound to a specific URL.
///
/// - Note: If you want to set up a parameter, you can change the appropriate property
///         or use the proper method. Both approaches are comparable and give the same result.
public struct Configuration: AgentConfiguration, Codable, Equatable {

    // MARK: - Public

    /// The base URL of the server. Corresponds to the address
    /// with which the configuration was created.
    public let url: URL

    /// A `String` that contains the name of the application.
    ///
    /// The default value corresponds to the value of `Bundle.main.bundleIdentifier`.
    public var appName: String? = ConfigurationDefaults.appName

    /// A `String` that contains the current application version.
    ///
    /// The default value corresponds to the value of `CFBundleShortVersionString`.
    public var appVersion: String? = ConfigurationDefaults.appVersion


    // MARK: - Private

    var sessionTimeout: Double = ConfigurationDefaults.sessionTimeout
    var maxSessionLength: Double = ConfigurationDefaults.maxSessionLength
    var recordingEnabled: Bool = ConfigurationDefaults.recordingEnabled


    // MARK: - Initialization

    /// Initializes new configuration for target URL.
    ///
    /// - Parameter url: The base URL of the server.
    public init(url: URL) {
        self.url = url
    }


    // MARK: - Builder methods

    /// Sets the name of the application.
    ///
    /// - Parameter appName: A `String` with the custom application name.
    ///
    /// - Returns: The updated configuration structure.
    @discardableResult
    public func appName(_ appName: String) -> Self {
        var updated = self
        updated.appName = appName

        return updated
    }

    /// Sets the version on the application.
    ///
    /// - Parameter appVersion: A `String` with the custom application version.
    ///
    /// - Returns: The updated configuration structure.
    @discardableResult
    public func appVersion(_ appVersion: String) -> Self {
        var updated = self
        updated.appVersion = appVersion

        return updated
    }
}
