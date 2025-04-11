//
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
import CiscoSwizzling
import CiscoInteractions
import SplunkSharedProtocols

extension Data: ModuleEventData {}

extension InteractionEvent: @retroactive Equatable {}
extension CiscoInteractions.InteractionEvent: ModuleEventMetadata {
    public static func == (lhs: CiscoInteractions.InteractionEvent, rhs: CiscoInteractions.InteractionEvent) -> Bool {
        lhs.id == rhs.id
    }

    public var timestamp: Date {
        time
    }
}


// Minimal implementation that ensures protocol conformance.
public struct InteractionsConfiguration: ModuleConfiguration {}

// Minimal implementation that ensures protocol conformance.
public struct InteractionsRemoteConfiguration: RemoteModuleConfiguration {

    // MARK: - Protocol compliance

    public var enabled: Bool = true

    public init?(from data: Data) {
        return nil
    }
}


public final class SplunkInteractions: Module {
    public func onPublish(data: @escaping (CiscoInteractions.InteractionEvent, Data) -> Void) {
        <#code#>
    }
    
    
    // MARK: - Module types

    public typealias Configuration = InteractionsConfiguration
    public typealias RemoteConfiguration = InteractionsRemoteConfiguration

    public typealias EventMetadata = InteractionEvent
    public typealias EventData = Data


    // MARK: - Module methods

    public func install(with configuration: (any ModuleConfiguration)?, remoteConfiguration: (any RemoteModuleConfiguration)?) {

    }


    // MARK: - Type transparency helpers

    public func deleteData(for metadata: any ModuleEventMetadata) {
        if let recordMetadata = metadata as? EventMetadata {
            deleteData(for: recordMetadata)
        }
    }
}
