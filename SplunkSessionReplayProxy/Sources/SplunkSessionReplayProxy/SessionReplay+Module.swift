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

import CiscoSessionReplay
import Foundation
import SplunkCommon

// IMPORTANT NOTES:
//
// This file declares conformance to `Module` protocol and related protocols.
// After creating the API proxy interface for the `SessionReplay` module, this code can be moved to another place.
//
//
// PURPOSE FOR THIS CODE:
//
// This definition assumes that the module has the same interface as is defined in the Module protocol
// but does not conform to this protocol because we do not want circular dependencies between modules and agents.
// In our situation, we must add this conformance in the Agent code by declaring that the module conforms to the protocol.
//
// If the module has the same interface, then it conforms (by default) to these protocols,
// and we do not need a code module interface (preferred way). But if serious reasons exist,
// we can add module conformance to any desired type.


/// `Data` can be used as an event type that the module produces.
extension Data: ModuleEventData {}

/// Struct `RecordMetadata` describes event metadata.
/// This type must be unique in the module/agent space.
extension Metadata: ModuleEventMetadata {
    public var timestamp: Date {
        Date(timeIntervalSince1970: Double(startUnixMs) / 1_000.0)
    }
}


/// Configuration for the Session Replay module.
///
/// - ``enabled``: Enables or disables the session replay. If disabled, subsequent calls to `start()` do nothing.
/// - ``samplingRate``: Optional local sampling of session replay recording in the `<0, 1>` range.
public struct SessionReplayConfiguration: ModuleConfiguration {

    /// Enables or disables the session replay.
    ///
    /// If disabled, subsequent calls to `start()` do nothing.
    /// Defaults to `true`.
    public var enabled: Bool

    /// Optional local sampling of session replay recording.
    ///
    /// The value sets the probability with which session replay is enabled.
    /// - `0` means session replay recording cannot be effectively enabled.
    /// - `0.5` means only half of sessions can be recorded.
    /// - `1` means all sessions can be recorded.
    /// - `nil` means the sampling rate is ignored (equivalent to `1`).
    ///
    /// If ``enabled`` is set to `false`, the sampling rate is ignored.
    /// Defaults to `nil`.
    public var samplingRate: Double?

    public init(enabled: Bool = true, samplingRate: Double? = nil) {
        self.enabled = enabled
        self.samplingRate = samplingRate
    }
}

/// Minimal implementation that ensures protocol conformance.
public struct SessionReplayRemoteConfiguration: RemoteModuleConfiguration {

    // MARK: - Internal decoding

    struct SessionReplay: Decodable {
        let enabled: Bool
    }

    struct MRUMRoot: Decodable {
        let sessionReplay: SessionReplay
    }

    struct Configuration: Decodable {
        let mrum: MRUMRoot
    }

    struct Root: Decodable {
        let configuration: Configuration
    }


    // MARK: - Protocol compliance

    public var enabled: Bool

    public init?(from data: Data) {
        guard let root = try? JSONDecoder().decode(Root.self, from: data) else {
            return nil
        }

        enabled = root.configuration.mrum.sessionReplay.enabled
    }
}


/// Defines SessionReplay conformance to `Module` protocol
/// and implements methods that are missing in the original `SessionReplay`.
extension SessionReplay: Module {

    // MARK: - Module types

    public typealias Configuration = SessionReplayConfiguration
    public typealias RemoteConfiguration = SessionReplayRemoteConfiguration

    public typealias EventMetadata = Metadata
    public typealias EventData = Data


    // MARK: - Module methods

    public func install(with _: (any ModuleConfiguration)?, remoteConfiguration _: (any RemoteModuleConfiguration)?) {
        // Initialize SessionReplay module
        _ = SessionReplay.instance
    }


    // MARK: - Type transparency helpers

    public func deleteData(for metadata: any ModuleEventMetadata) {
        if let recordMetadata = metadata as? EventMetadata {
            deleteData(for: recordMetadata)
        }
    }
}
