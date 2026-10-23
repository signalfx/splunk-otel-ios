/*
Copyright 2026 Splunk Inc.

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

/// Event metadata used to satisfy the agent module contract.
public struct AppHangMonitorMetadata: ModuleEventMetadata {

    // MARK: - Public

    public let timestamp: Date


    // MARK: - Internal

    let id: UUID

    public static func == (lhs: AppHangMonitorMetadata, rhs: AppHangMonitorMetadata) -> Bool {
        lhs.id == rhs.id
    }
}

/// Event data used to satisfy the agent module contract.
public struct AppHangMonitorData: ModuleEventData {}

extension AppHangMonitor: Module {

    // MARK: - Module types

    public typealias Configuration = AppHangMonitorConfiguration
    public typealias RemoteConfiguration = AppHangMonitorRemoteConfiguration
    public typealias EventMetadata = AppHangMonitorMetadata
    public typealias EventData = AppHangMonitorData


    // MARK: - Module methods

    public func deleteData(for _: any ModuleEventMetadata) {}

    public func onPublish(data _: @escaping (AppHangMonitorMetadata, AppHangMonitorData) -> Void) {}
}
