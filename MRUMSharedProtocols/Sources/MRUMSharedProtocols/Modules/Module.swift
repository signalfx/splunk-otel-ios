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


// MARK: - Internal Module API

/// Data of events emitted by a Module.
public protocol ModuleEventData {}

/// Metadata describing Events emitted by a Module.
public protocol ModuleEventMetadata: Equatable {

    // MARK: - Identification

    /// Event timestamp.
    ///
    /// Timestamp is used to associate the emitted data with the corresponding Session.
    var timestamp: Date { get }
}


/// Internal Module protocol.
///
/// The protocol is used internally by Agent to manage Modules and their Events.
public protocol Module {

    // MARK: - Associated types

    associatedtype Configuration: ModuleConfiguration
    associatedtype RemoteConfiguration: RemoteModuleConfiguration

    associatedtype EventMetadata: ModuleEventMetadata
    associatedtype EventData: ModuleEventData


    // MARK: - Initialization

    /// Creates an module instance.
    init()

    /// Initialize the Module.
    /// - Parameter configuration: A Module-specific configuration.
    func install(with configuration: ModuleConfiguration?, remoteConfiguration: RemoteModuleConfiguration?)


    // MARK: - Data producer API

    /// Module event publisher.
    ///
    /// Module calls the provided method for each emitted Event. The Event is then kept
    /// by the Module till `deleteData(for:)` method is called with the corresponding Metadata.
    ///
    /// - Parameter data: Callback function called for every Event emitted by Module.
    func onPublish(data: @escaping (EventMetadata, EventData) -> Void)

    /// Event processing confirmation.
    ///
    /// Agent calls this method to confirm that the Event identified by the Metadata is processed
    /// and no longer needs be kept by the Module for eventual re-emission.
    ///
    /// - Parameter metadata: Metadata uniquely identifying the Event.
    func deleteData(for metadata: any ModuleEventMetadata)
}
