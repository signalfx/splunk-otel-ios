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


public struct NetworkInfoData: ModuleEventData {}

public struct NetworkInfoMetadata: ModuleEventMetadata {
    public var timestamp = Date()
    public var eventName: String = "network.change"
}

extension NetworkInfo: Module {

    // MARK: - Module types

    public typealias Configuration = NetworkInfoConfiguration
    public typealias RemoteConfiguration = NetworkInfoRemoteConfiguration

    public typealias EventMetadata = NetworkInfoMetadata
    public typealias EventData = NetworkInfoData


    // MARK: - Module methods

    public func install(with configuration: (any ModuleConfiguration)?, remoteConfiguration: (any RemoteModuleConfiguration)?) {
        startDetection()
    }


    // MARK: - Type transparency helpers

    public func deleteData(for metadata: any ModuleEventMetadata) {}
    public func onPublish(data: @escaping (NetworkInfoMetadata, NetworkInfoData) -> Void) {}
}
