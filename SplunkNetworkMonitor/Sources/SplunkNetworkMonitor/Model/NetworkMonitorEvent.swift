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

/// Represents Network Change span's data.
struct NetworkMonitorEvent {
    var timestamp: Date
    var isConnected: Bool
    var connectionType: ConnectionType
    var radioType: String?
}

// MARK: - Comparison Extension

extension NetworkMonitorEvent {

    /// Compares two NetworkMonitorEvents to determine if they represent different network states.
    /// Excludes the timestamp from comparison as it will always be different, but
    /// returns false if they are less than 3 ms apart to reduce noise
    /// 
    /// - Parameter other: The NetworkMonitorEvent to compare against
    /// - Returns: `true` if the events represent different network states, `false` if they are the same or noise
    func isDebouncedChange(from other: NetworkMonitorEvent) -> Bool {
        let timeDifference = abs(timestamp.timeIntervalSince(other.timestamp))
        if timeDifference < 0.003 {
            return false
        }

        return isConnected != other.isConnected ||
               connectionType != other.connectionType ||
               radioType != other.radioType
    }
}
