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

/// A placeholder data structure for `SlowFrameDetector` events, conforming to `ModuleEventData`.
///
/// This module emits spans directly and does not require a specific data payload for its events.
public struct SlowFrameData: ModuleEventData {}

extension EventMetadataSlowFrameDetector: ModuleEventMetadata {
    /// Conformance to the `Equatable` protocol.
    ///
    /// - Parameters:
    ///   - lhs: The left-hand side instance to compare.
    ///   - rhs: The right-hand side instance to compare.
    /// - Returns: `true` if selected properties are equal; otherwise, `false`.
    public static func == (lhs: EventMetadataSlowFrameDetector, rhs: EventMetadataSlowFrameDetector) -> Bool {
        return lhs.timestamp == rhs.timestamp
                   && lhs.id == rhs.id
    }
}

/// Defines SlowFrameDetector conformance to `Module` protocol
/// and implements methods that are missing in the original `SlowFrameDetector`.
extension SlowFrameDetector: Module {

    // MARK: - Module types

    public typealias Configuration = SlowFrameDetectorConfiguration
    public typealias RemoteConfiguration = SlowFrameDetectorRemoteConfiguration
    public typealias EventMetadata = EventMetadataSlowFrameDetector
    public typealias EventData = SlowFrameData


    // MARK: - Module methods


    /// A placeholder implementation for data deletion, which is not required for this module.
    ///
    /// - Parameter metadata: The metadata for which data should be deleted. This parameter is ignored.
    public func deleteData(for metadata: any ModuleEventMetadata) {
        // In SlowFrameDetector we don't have any data to delete.
    }

    /// A placeholder implementation for the data publishing hook.
    ///
    /// The `SlowFrameDetector` emits spans directly and does not use this callback mechanism.
    ///
    /// - Parameter data: A closure to be called when new data is available. This parameter is ignored.
    public func onPublish(data: @escaping (EventMetadataSlowFrameDetector, SlowFrameData) -> Void) {
        // We are emitting spans directly instead of using this.
    }
}
