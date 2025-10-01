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

/// ModuleConfiguration conformance.
public struct WebViewInstrumentationConfiguration: ModuleConfiguration {}

/// RemoteModuleConfiguration conformance.
public struct WebViewRemoteConfiguration: RemoteModuleConfiguration {

    /// This property indicates whether the WebViewInstrumentationModule should be enabled
    /// according to the remote configuration.
    public var enabled: Bool = true

    /// Initializes the remote configuration from data. This module does not support remote configuration beyond enabling/disabling.
    public init?(from _: Data) {
        nil
    }
}

/// Placeholder metadata for events produced by `WebViewInstrumentation`. This module does not produce events.
public struct WebViewInstrumentationMetadata: ModuleEventMetadata {
    /// The timestamp of the event.
    public var timestamp = Date()
}

/// Placeholder data for events produced by `WebViewInstrumentation`. This module does not produce events.
public struct WebViewInstrumentationData: ModuleEventData {}

/// Module conformance.
extension WebViewInstrumentation: Module {

    public typealias Configuration = WebViewInstrumentationConfiguration
    public typealias RemoteConfiguration = WebViewRemoteConfiguration
    public typealias EventMetadata = WebViewInstrumentationMetadata
    public typealias EventData = WebViewInstrumentationData

    /// When enabled, allows the injection of the necessary JavaScript bridge into a given `WKWebView`
    /// to enable a BRUM (Browser RUM) instance instrumenting web content to access the native RUM
    /// agent Session ID.
    public func install(
        with _: (any ModuleConfiguration)?,
        remoteConfiguration _: (any SplunkCommon.RemoteModuleConfiguration)?
    ) {}

    public func onPublish(data _: @escaping (WebViewInstrumentationMetadata, WebViewInstrumentationData) -> Void) {}

    public func deleteData(for _: any SplunkCommon.ModuleEventMetadata) {}
}
