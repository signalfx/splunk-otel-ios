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

// ModuleConfiguration conformance
/// A placeholder for local configuration of the WebView Instrumentation module.
public struct WebViewInstrumentationConfiguration: ModuleConfiguration {}

// RemoteModuleConfiguration conformance
/// A placeholder structure for remote configuration of the WebView Instrumentation module.
public struct WebViewInstrumentationRemoteConfiguration: RemoteModuleConfiguration {
    /// A Boolean value indicating whether the module is enabled.
    /// - Note: This property is part of the protocol conformance but is not currently used.
    public var enabled: Bool

    /// Initializes the remote configuration.
    /// - Note: This initializer is a placeholder and always returns `nil`, as remote configuration is not yet implemented for this module.
    /// - Parameter data: The remote configuration data. This parameter is ignored.
    public init?(from data: Data) {
        return nil
    }
}

/// Extends `WebViewInstrumentation` to conform to the `Module` protocol, enabling its integration within the agent framework.
extension WebViewInstrumentation: Module {

    public typealias Configuration = WebViewInstrumentationConfiguration
    public typealias RemoteConfiguration = WebViewInstrumentationRemoteConfiguration

    // Module conformance
    public typealias EventMetadata = WebViewInstrumentationMetadata
    public typealias EventData = WebViewInstrumentationData

    /// A placeholder for the module installation logic.
    ///
    /// - Note: This method is a no-op, as the primary functionality is exposed through the `injectSessionId(into:)` method.
    /// - Parameters:
    ///   - configuration: The local configuration. This parameter is currently unused.
    ///   - remoteConfiguration: The remote configuration. This parameter is currently unused.
    public func install(
        with configuration: (any ModuleConfiguration)?,
        remoteConfiguration: (any SplunkCommon.RemoteModuleConfiguration)?
    ) {}

    /// A placeholder for registering a callback to publish event data.
    ///
    /// - Note: This method is a no-op as the WebView Instrumentation module does not publish data through this mechanism.
    /// - Parameter data: A closure to be called when new event data is available.
    public func onPublish(data: @escaping (WebViewInstrumentationMetadata, WebViewInstrumentationData) -> Void) {}

    /// A placeholder for handling the deletion of data associated with a specific event.
    ///
    /// - Note: This method is a no-op as the WebView Instrumentation module does not persist data that requires explicit deletion.
    /// - Parameter metadata: The metadata of the event whose data should be deleted.
    public func deleteData(for metadata: any SplunkCommon.ModuleEventMetadata) {}
}
