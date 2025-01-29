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

@_implementationOnly import SplunkSharedProtocols

extension Module {

    // MARK: - Type acceptance helpers

    /// Verifies that the module accepts the configuration type.
    ///
    /// - Parameter type: A type of configuration.
    /// - Returns: `true` if the module understands the type.
    static func acceptsConfiguration(type: Any.Type) -> Bool {
        Configuration.self == type
    }

    /// Verifies that the module accepts the remote configuration type.
    ///
    /// - Parameter type: A type of remote configuration.
    /// - Returns: `true` if the module understands the type.
    static func acceptsRemoteConfiguration(type: Any.Type) -> Bool {
        RemoteConfiguration.self == type
    }

    /// Verifies that the module accepts the metadata type.
    ///
    /// - Parameter type: A type of module metadata.
    /// - Returns: `true` if the module understands the type.
    static func acceptsMetadata(type: Any.Type) -> Bool {
        EventMetadata.self == type
    }
}
