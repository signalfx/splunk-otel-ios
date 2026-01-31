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

/// A placeholder data structure for `SlowFrameDetector` module events.
public struct SlowFrameData: ModuleEventData {}

// ModuleEventMetadata Conformance

extension EventMetadataSlowFrameDetector: ModuleEventMetadata {
    public static func == (lhs: EventMetadataSlowFrameDetector, rhs: EventMetadataSlowFrameDetector) -> Bool {
        lhs.timestamp == rhs.timestamp
            && lhs.id == rhs.id
    }
}

// Module Conformance

extension SlowFrameDetector: Module {

    // MARK: - Module types

    public typealias Configuration = SlowFrameDetectorConfiguration
    public typealias RemoteConfiguration = SlowFrameDetectorRemoteConfiguration

    public typealias EventMetadata = EventMetadataSlowFrameDetector
    public typealias EventData = SlowFrameData


    // MARK: - Module methods

    public func deleteData(for _: any ModuleEventMetadata) {
        // In SlowFrameDetector we don't have any data to delete.
    }

    public func onPublish(data _: @escaping (EventMetadataSlowFrameDetector, SlowFrameData) -> Void) {
        // We are emitting spans directly instead of using this.
    }
}
