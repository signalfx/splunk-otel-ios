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
import SplunkSharedProtocols


// MARK: - TrackableData Protocol

public protocol TrackableData: SplunkTrackable {
    /// Category of the data, used for grouping
    var category: String { get }

    /// The values to be tracked
    var values: [String: EventAttributeValue] { get }

}



// MARK: - Default Implementation

public extension TrackableData {

    func toEventAttributes() -> [String: EventAttributeValue] {
        var attributes = values

        return attributes
    }
}
