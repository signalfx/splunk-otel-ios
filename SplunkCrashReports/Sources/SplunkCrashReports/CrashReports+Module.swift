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

// `String` can be used as an event type that the module produces.
// This is due to the fact the Crash Reports module serializes
// the whole Crash payload JSON in place to `String`.
extension String: ModuleEventData {}

/// Describes the Crash Report event metadata.
public struct CrashReportsMetadata: ModuleEventMetadata {
    public var timestamp: Date = Date()
    public var eventName: String = CrashReportKeys.eventName
}

extension CrashReports : Module {
    
    // MARK: - Module types

    public typealias Configuration = CrashReportsConfiguration
    public typealias RemoteConfiguration = CrashReportsRemoteConfiguration

    public typealias EventMetadata = CrashReportsMetadata
    public typealias EventData = String


    // MARK: - Module event data publishing

    public func onPublish(data block: @escaping (CrashReportsMetadata, String) -> Void) {
       crashReportDataConsumer = block
    }

    // An empty implementation as the purging of the actual crash report data
    // is handled by the PL Crash Reporter internally.
    public func deleteData(for metadata: any ModuleEventMetadata) {}
}
