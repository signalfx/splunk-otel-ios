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
import CiscoInteractions

public struct InteractionEventData: ModuleEventData {
    var elementId: ObjectIdentifier?
    var type: String
}

extension InteractionEvent: @retroactive Equatable {}

extension CiscoInteractions.InteractionEvent: ModuleEventMetadata {
    public static func == (lhs: CiscoInteractions.InteractionEvent, rhs: CiscoInteractions.InteractionEvent) -> Bool {
        lhs.id == rhs.id
    }

    public var timestamp: Date {
        time
    }
}

extension Interactions: Module {

    // MARK: - Module types

    public typealias Configuration = SplunkInteractionsConfiguration
    public typealias RemoteConfiguration = SplunkInteractionsRemoteConfiguration

    public typealias EventMetadata = InteractionEvent
    public typealias EventData = InteractionEventData


    // MARK: - Module methods

    public func install(with configuration: (any ModuleConfiguration)?, remoteConfiguration: (any RemoteModuleConfiguration)?) {
        startInteractionsDetection()
    }


    // MARK: - Type transparency helpers

    public func onPublish(data: @escaping (CiscoInteractions.InteractionEvent, InteractionEventData) -> Void) {}
    public func deleteData(for metadata: any ModuleEventMetadata) {}
}
