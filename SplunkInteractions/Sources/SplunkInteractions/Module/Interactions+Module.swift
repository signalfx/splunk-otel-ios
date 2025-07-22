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

import CiscoInteractions
import Foundation
import SplunkCommon

/// A data structure containing supplementary information about a detected user interaction event.
public struct InteractionEventData: ModuleEventData {
    var elementId: ObjectIdentifier?
    var type: String
}

extension InteractionEvent: @retroactive Equatable {}

extension CiscoInteractions.InteractionEvent: ModuleEventMetadata {
    /// Conformance to the `Equatable` protocol.
    ///
    /// - Parameters:
    ///   - lhs: The left-hand side instance to compare.
    ///   - rhs: The right-hand side instance to compare.
    /// - Returns: `true` if `id` properties are equal; otherwise, `false`.
    public static func == (lhs: CiscoInteractions.InteractionEvent, rhs: CiscoInteractions.InteractionEvent) -> Bool {
        lhs.id == rhs.id
    }

    /// The timestamp when the interaction event occurred.
    public var timestamp: Date {
        time
    }
}

extension Interactions: Module {

    // MARK: - Module types

    /// The configuration type for the `Interactions` module, conforming to ``ModuleConfiguration``.
    public typealias Configuration = InteractionsConfiguration
    /// The remote configuration type for the `Interactions` module, conforming to ``RemoteModuleConfiguration``.
    public typealias RemoteConfiguration = InteractionsRemoteConfiguration

    /// The type representing the metadata for an interaction event, conforming to ``ModuleEventMetadata``.
    public typealias EventMetadata = InteractionEvent
    /// The type representing the supplementary data for an interaction event, conforming to ``ModuleEventData``.
    public typealias EventData = InteractionEventData


    // MARK: - Module methods

    /// Installs and configures the `Interactions` module.
    ///
    /// This method is called during the agent's initialization process. It starts the user interaction detection
    /// if the module is enabled in the provided configuration.
    /// - Parameters:
    ///   - configuration: The local configuration for the module.
    ///   - remoteConfiguration: The remote configuration for the module. This parameter is ignored.
    public func install(with configuration: (any ModuleConfiguration)?, remoteConfiguration: (any RemoteModuleConfiguration)?) {
        let configuration = configuration as? Configuration

        // Start the interactions detection in the module (unless it is explicitly disabled)
        if configuration?.isEnabled ?? true {
            startInteractionsDetection()
        }
    }


    // MARK: - Type transparency helpers

    /// A placeholder method to conform to the `Module` protocol.
    ///
    /// - Note: This method is not implemented and has no effect in the `Interactions` module.
    public func onPublish(data: @escaping (CiscoInteractions.InteractionEvent, InteractionEventData) -> Void) {}

    /// A placeholder method to conform to the `Module` protocol.
    ///
    /// - Note: This method is not implemented and has no effect in the `Interactions` module.
    public func deleteData(for metadata: any ModuleEventMetadata) {}
}
