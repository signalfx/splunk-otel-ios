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
import SplunkSharedProtocols

public struct NetworkInstrumentationData: ModuleEventData {}

public struct NetworkInstrumentationMetadata: ModuleEventMetadata {
    public var timestamp: Date = Date()
}

extension NetworkInstrumentation: Module {

    // MARK: - Module types

    public typealias Configuration = NetworkInstrumentationConfiguration
    public typealias RemoteConfiguration = NetworkInstrumentationRemoteConfiguration

    public typealias EventMetadata = NetworkInstrumentationMetadata
    public typealias EventData = NetworkInstrumentationData

    // MARK: - Type transparency helpers

    // An empty implementation as the module publishes data internally through the OTel trace exporter SDK.
    public func onPublish(data: @escaping (NetworkInstrumentationMetadata, NetworkInstrumentationData) -> Void) {}

    // An empty implementation as the module does not store any data.
    public func deleteData(for metadata: any ModuleEventMetadata) {}
}
