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

// MARK: - Module Configuration

/// Configuration for the `WebViewInstrumentation` module. This is a placeholder as the module currently has no user-configurable options.
public struct WebViewInstrumentationConfiguration: ModuleConfiguration {}

// swiftlint:disable type_name
/// Remote configuration for the `WebViewInstrumentation` module.
public struct WebViewInstrumentationRemoteConfiguration: RemoteModuleConfiguration {
    /// A boolean flag to enable or disable the module remotely.
    public var enabled: Bool = true

    /// Initializes the remote configuration from data. This module does not support remote configuration beyond enabling/disabling.
    public init?(from data: Data) {
        return nil
    }
} // swiftlint:enable type_name

// MARK: - Module Events

/// Placeholder metadata for events produced by `WebViewInstrumentation`. This module does not produce events.
public struct WebViewInstrumentationMetadata: ModuleEventMetadata {
    /// The timestamp of the event.
    public var timestamp = Date()
}

/// Placeholder data for events produced by `WebViewInstrumentation`. This module does not produce events.
public struct WebViewInstrumentationData: ModuleEventData {}

// MARK: - Module Conformance

extension WebViewInstrumentation: Module {

    public typealias Configuration = WebViewInstrumentationConfiguration
    public typealias RemoteConfiguration = WebViewInstrumentationRemoteConfiguration
    public typealias EventMetadata = WebViewInstrumentationMetadata
    public typealias EventData = WebViewInstrumentationData

    public func install(
        with configuration: (any ModuleConfiguration)?,
        remoteConfiguration: (any SplunkCommon.RemoteModuleConfiguration)?
    ) {}

    public func onPublish(data: @escaping (WebViewInstrumentationMetadata, WebViewInstrumentationData) -> Void) {}

    public func deleteData(for metadata: any SplunkCommon.ModuleEventMetadata) {}
}
