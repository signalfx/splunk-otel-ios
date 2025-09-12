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
public struct WebViewInstrumentationConfiguration: ModuleConfiguration {}

// RemoteModuleConfiguration conformance
// swiftlint:disable type_name
public struct WebViewInstrumentationRemoteConfiguration: RemoteModuleConfiguration {
    public var enabled: Bool = true

    public init?(from data: Data) {
        return nil
    }
}
// swiftlint:enable type_name

// Add placeholder types to satisfy Module conformance, as this module does not produce events.
public struct WebViewInstrumentationMetadata: ModuleEventMetadata {
    public var timestamp = Date()
}

public struct WebViewInstrumentationData: ModuleEventData {}

extension WebViewInstrumentation: Module {

    public typealias Configuration = WebViewInstrumentationConfiguration
    public typealias RemoteConfiguration = WebViewInstrumentationRemoteConfiguration

    // Module conformance
    public typealias EventMetadata = WebViewInstrumentationMetadata
    public typealias EventData = WebViewInstrumentationData

    public func install(
        with configuration: (any ModuleConfiguration)?,
        remoteConfiguration: (any SplunkCommon.RemoteModuleConfiguration)?
    ) {}

    public func onPublish(data: @escaping (WebViewInstrumentationMetadata, WebViewInstrumentationData) -> Void) {}

    public func deleteData(for metadata: any SplunkCommon.ModuleEventMetadata) {}
}
